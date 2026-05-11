function eventChain = generate_event_chain(caseData, scenarioType, opts)
%GENERATE_EVENT_CHAIN Probabilistic cascading event-chain generator for EH-IES.
%
% Section 5.1 / 5.4 module: test-system and extreme event-chain configuration.
%
% Syntax:
%   eventChain = generate_event_chain(caseData, scenarioType, opts)
%
% Inputs:
%   caseData     - IEEE 33-bus EH-IES data structure.
%   scenarioType - 'storm', 'wildfire', or 'ice_disaster'.
%   opts         - optional struct with fields:
%                  .seed        reproducibility seed, default 2026
%                  .makePlots   true/false event-chain visualisation, default false
%                  .resultDir   directory for figures, default []
%
% Outputs:
%   eventChain.events(k)       - event type, occurrence time, duration, severity,
%                                affected buses and affected lines.
%   eventChain.lineStatus      - Nl x T binary matrix, 1 available, 0 failed.
%   eventChain.busAvailability - Nb x T binary matrix, 1 energizable, 0 isolated by damage.
%   eventChain.renewableDerating.pv / .wt - 1 x T renewable availability factors.
%   eventChain.islandInfo{t}   - connected components of available topology.
%   eventChain.propagation     - conditional probability matrix P(e_j | e_i).
%
% Equations mapping:
%   (1) Cascading propagation: I_j ~ Bernoulli(P(e_j | e_i) * severity_i).
%   (2) Line availability: a_l(t)=prod_e 1{l notin L_e or t notin [tau_e,tau_e+d_e)}.
%   (3) RES derating: rho_RES(t)=min_e{1-severity_e * alpha_e} for renewable events.
%   (4) Island partition: G_t=(B,L_t), islands are connected components of G_t.

if nargin < 2 || isempty(scenarioType), scenarioType = 'storm'; end
if nargin < 3 || isempty(opts), opts = struct(); end
if ~ismember(scenarioType, {'storm','wildfire','ice_disaster'})
    error('generate_event_chain:UnknownScenario', 'scenarioType must be storm, wildfire, or ice_disaster.');
end
opts = fill_event_options(opts);

rng(opts.seed);
T = caseData.T; Nl = caseData.Nl; Nb = caseData.Nb;
lineStatus = true(Nl,T);
busAvailability = true(Nb,T);
pvDerating = ones(1,T);
wtDerating = ones(1,T);

% Ordered event templates: T-outage -> RES collapse -> feeder failures ->
% islanding -> sequential component failures. Probabilities are scenario-specific.
template = scenario_templates(caseData, scenarioType);
Nevt = numel(template);
P = propagation_matrix(scenarioType, Nevt);
active = false(1,Nevt); active(1) = true;

for i = 1:Nevt-1
    if active(i)
        for j = i+1:Nevt
            pij = min(0.98, P(i,j) * (0.50 + template(i).severity));
            active(j) = active(j) || (rand <= pij);
        end
    end
end
% Enforce islanding if any upstream/feeder event occurs, because subsequent MILP
% needs explicit islanded hours.
active(strcmp({template.type}, 'islanding formation')) = any(active(1:min(3,Nevt)));

events = template(active);
for e = 1:numel(events)
    idx = events(e).time:min(T, events(e).time + events(e).duration - 1);
    if ~isempty(events(e).affectedLines)
        lineStatus(events(e).affectedLines, idx) = false;
    end
    if ~isempty(events(e).affectedBuses)
        busAvailability(events(e).affectedBuses, idx) = false;
    end
    switch events(e).type
        case 'renewable output collapse'
            pvDerating(idx) = min(pvDerating(idx), max(0.05, 1 - events(e).severity * events(e).pvImpact));
            wtDerating(idx) = min(wtDerating(idx), max(0.05, 1 - events(e).severity * events(e).wtImpact));
        case 'storm-induced transmission outage'
            % Transmission outage is represented by gridAvailable below.
        case 'sequential component failure'
            pvDerating(idx) = min(pvDerating(idx), max(0.10, 1 - 0.20*events(e).severity));
    end
end

% Convert event-chain data to optimization-compatible fields.
gridAvailable = true(1,T);
for e = 1:numel(events)
    if strcmp(events(e).type, 'storm-induced transmission outage') || strcmp(events(e).type, 'wildfire transmission derating') || strcmp(events(e).type, 'ice-induced transmission outage')
        idx = events(e).time:min(T, events(e).time + events(e).duration - 1);
        gridAvailable(idx) = false;
    end
end

islandInfo = cell(1,T);
for t = 1:T
    islandInfo{t} = compute_islands(caseData, lineStatus(:,t), busAvailability(:,t));
end

% Build fault and repair abstractions for downstream restoration MILP.
faultedLines = find(any(~lineStatus,2))';
earliestRepairHour = containers.Map('KeyType','double','ValueType','double');
faultStartHour = containers.Map('KeyType','double','ValueType','double');
for l = faultedLines
    firstFail = find(~lineStatus(l,:), 1, 'first');
    lastFail = find(~lineStatus(l,:), 1, 'last');
    if isempty(firstFail)
        faultStartHour(l) = T + 1;
        earliestRepairHour(l) = 1;
    else
        faultStartHour(l) = firstFail;
        earliestRepairHour(l) = min(T, max(1, lastFail + 1));
    end
end

stage = strings(1,T);
stage(1:max(1,min([events.time])-1)) = "pre-event";
eventHours = any(~lineStatus,1) | ~gridAvailable | pvDerating < 0.95 | wtDerating < 0.95;
for t = 1:T
    if stage(t) == ""
        if eventHours(t)
            stage(t) = "during-event-islanded";
        else
            stage(t) = "post-event-restoration";
        end
    end
end
firstEvent = find(eventHours,1,'first'); if isempty(firstEvent), firstEvent = 6; end
stage(1:firstEvent-1) = "pre-event";
lastEvent = find(eventHours,1,'last'); if ~isempty(lastEvent) && lastEvent < T, stage(lastEvent+1:T) = "post-event-restoration"; end

eventChain = struct();
eventChain.name = scenarioType;
eventChain.description = sprintf('Probabilistic %s cascading event-chain for resilience-oriented EH-IES scheduling.', scenarioType);
eventChain.T = T;
eventChain.time = 1:T;
eventChain.stage = stage;
eventChain.isPre = stage == "pre-event";
eventChain.isDuring = stage == "during-event-islanded";
eventChain.isPost = stage == "post-event-restoration";
eventChain.events = events;
eventChain.propagation = P(active, active);
eventChain.lineStatus = lineStatus;
eventChain.busAvailability = busAvailability;
eventChain.renewableDerating.pv = pvDerating;
eventChain.renewableDerating.wt = wtDerating;
eventChain.pvMultiplier = pvDerating;
eventChain.wtMultiplier = wtDerating;
eventChain.gridAvailable = gridAvailable;
eventChain.branchAvailableBase = lineStatus;
eventChain.faultedLines = faultedLines;
eventChain.earliestRepairHour = earliestRepairHour;
eventChain.faultStartHour = faultStartHour;
eventChain.islandInfo = islandInfo;
eventChain.criticalBuses = [6 18 25 30 33];
eventChain.minH2ReserveAtEvent = 0.65 * caseData.h2.Hmax;
eventChain.minBessReserveAtEvent = 0.55 * caseData.bess.Emax;

if opts.makePlots
    visualize_event_chain(eventChain, caseData, opts.resultDir);
end
end

function template = scenario_templates(caseData, scenarioType)
base = struct('type','','time',0,'duration',0,'severity',0,'affectedBuses',[],'affectedLines',[],'pvImpact',0,'wtImpact',0);
switch scenarioType
    case 'storm'
        template = repmat(base,1,5);
        template(1) = make_event('storm-induced transmission outage',6,10,0.90,[],[],0,0);
        template(2) = make_event('renewable output collapse',7,8,0.75,[],[],0.80,0.55);
        template(3) = make_event('distribution feeder failure',8,8,0.80,[],[6 7 27 28 29 30 31],0,0);
        template(4) = make_event('islanding formation',8,10,0.70,[18 30 33],[],0,0);
        template(5) = make_event('sequential component failure',12,4,0.45,[24 25],find(ismember(caseData.branch,[24 25],'rows')),0.20,0.20);
    case 'wildfire'
        template = repmat(base,1,5);
        template(1) = make_event('wildfire transmission derating',5,12,0.80,[],[],0,0);
        template(2) = make_event('renewable output collapse',6,10,0.65,[],[],0.70,0.35);
        template(3) = make_event('distribution feeder failure',7,12,0.85,[],[23 24 25 26 27 28 29],0,0);
        template(4) = make_event('islanding formation',7,13,0.78,[24 25 30 33],[],0,0);
        template(5) = make_event('sequential component failure',14,5,0.55,[30 31 32],30:32,0.15,0.15);
    case 'ice_disaster'
        template = repmat(base,1,5);
        template(1) = make_event('ice-induced transmission outage',4,15,0.95,[],[],0,0);
        template(2) = make_event('renewable output collapse',4,14,0.85,[],[],0.55,0.75);
        template(3) = make_event('distribution feeder failure',6,14,0.90,[],[4 5 6 7 8 9 10 11 12],0,0);
        template(4) = make_event('islanding formation',6,15,0.85,[6 18 30 33],[],0,0);
        template(5) = make_event('sequential component failure',11,8,0.60,[14 15 16],13:16,0.20,0.25);
end
end

function e = make_event(type,time,duration,severity,buses,lines,pvImpact,wtImpact)
e = struct('type',type,'time',time,'duration',duration,'severity',severity, ...
    'affectedBuses',buses,'affectedLines',lines,'pvImpact',pvImpact,'wtImpact',wtImpact);
end

function P = propagation_matrix(scenarioType, Nevt)
P = zeros(Nevt);
switch scenarioType
    case 'storm'
        vals = [0.90 0.82 0.70 0.45];
    case 'wildfire'
        vals = [0.70 0.92 0.82 0.55];
    case 'ice_disaster'
        vals = [0.86 0.88 0.90 0.70];
end
for i = 1:Nevt-1
    P(i,i+1) = vals(i);
    if i+2 <= Nevt, P(i,i+2) = 0.35*vals(i); end
end
end

function islands = compute_islands(caseData, lineAvailable, busAvailable)
A = caseData.branch(lineAvailable,:);
if isempty(A)
    comp = (1:caseData.Nb)';
else
    G = graph(A(:,1), A(:,2), [], caseData.Nb);
    comp = conncomp(G)';
end
comp(~busAvailable) = 0;
ids = unique(comp(comp>0));
islands = struct('id',{},'buses',{},'hasGrid',{},'hasHydrogenHub',{},'hasBlackStart',{});
for k = 1:numel(ids)
    buses = find(comp == ids(k))';
    islands(k).id = ids(k); %#ok<AGROW>
    islands(k).buses = buses; %#ok<AGROW>
    islands(k).hasGrid = any(buses == caseData.slackBus); %#ok<AGROW>
    islands(k).hasHydrogenHub = any(buses == caseData.h2.bus); %#ok<AGROW>
    islands(k).hasBlackStart = any(ismember(buses, caseData.blackStartBuses)); %#ok<AGROW>
end
end

function visualize_event_chain(eventChain, caseData, resultDir)
if isempty(resultDir), resultDir = pwd; end
if ~exist(resultDir,'dir'), mkdir(resultDir); end

fig = figure('Name','Event Propagation Graph','Color','w','Position',[100 100 850 420]);
N = numel(eventChain.events);
names = string({eventChain.events.type});
s = []; t = []; w = [];
for i = 1:N
    for j = i+1:N
        if eventChain.propagation(i,j) > 0
            s(end+1) = i; t(end+1) = j; w(end+1) = eventChain.propagation(i,j); %#ok<AGROW>
        end
    end
end
G = digraph(s,t,w,names);
plot(G,'Layout','layered','LineWidth',max(1,4*G.Edges.Weight),'NodeFontSize',10,'ArrowSize',12);
title('Probabilistic Event Propagation Graph P(e_j|e_i)');
exportgraphics(fig, fullfile(resultDir,'Fig_event_propagation_graph.png'), 'Resolution', 600);

fig = figure('Name','Outage Timeline','Color','w','Position',[120 120 950 430]); hold on;
for e = 1:N
    rectangle('Position',[eventChain.events(e).time, e-0.35, eventChain.events(e).duration, 0.7], ...
        'FaceColor',[0.85 0.25 0.20 0.25+0.5*eventChain.events(e).severity], 'EdgeColor',[0.55 0.1 0.1]);
    text(eventChain.events(e).time+0.1,e,names(e),'VerticalAlignment','middle','FontSize',9);
end
xlim([1 eventChain.T+1]); ylim([0 N+1]); grid on; box on;
xlabel('Time (h)'); ylabel('Event index'); title('Cascading Outage Timeline');
exportgraphics(fig, fullfile(resultDir,'Fig_outage_timeline.png'), 'Resolution', 600);

fig = figure('Name','Topology Fragmentation','Color','w','Position',[140 140 900 420]);
frag = zeros(1,eventChain.T); largest = zeros(1,eventChain.T);
for tt = 1:eventChain.T
    frag(tt) = numel(eventChain.islandInfo{tt});
    if frag(tt) > 0
        largest(tt) = max(arrayfun(@(x) numel(x.buses), eventChain.islandInfo{tt}));
    end
end
yyaxis left; stairs(1:eventChain.T, frag, '-o'); ylabel('Number of islands');
yyaxis right; stairs(1:eventChain.T, largest, '-s'); ylabel('Largest island size (buses)');
xlabel('Time (h)'); title('Topology Fragmentation Evolution'); grid on; box on;
exportgraphics(fig, fullfile(resultDir,'Fig_topology_fragmentation.png'), 'Resolution', 600);
end

function opts = fill_event_options(opts)
if ~isfield(opts,'seed'), opts.seed = 2026; end
if ~isfield(opts,'makePlots'), opts.makePlots = false; end
if ~isfield(opts,'resultDir'), opts.resultDir = ''; end
end
