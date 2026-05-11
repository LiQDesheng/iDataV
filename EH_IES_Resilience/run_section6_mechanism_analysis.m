function section6 = run_section6_mechanism_analysis(opts)
%RUN_SECTION6_MECHANISM_ANALYSIS Complete Section 6 mechanism-analysis workflow.
%
% Scientific mechanisms quantified:
%   6.1 Multi-timescale resilience mechanism
%   6.2 Hydrogen survivability enhancement
%   6.3 Battery vs hydrogen functional division
%   6.4 Event-chain severity evolution
%   6.5 Hydrogen-driven restoration reshaping
%   6.6 Resilience-economy tradeoff

if nargin < 1, opts = struct(); end
rootDir = fileparts(mfilename('fullpath'));
addpath(rootDir, fullfile(rootDir,'data'), fullfile(rootDir,'functions'), ...
    fullfile(rootDir,'optimization'), fullfile(rootDir,'plotting'), fullfile(rootDir,'scenarios'), fullfile(rootDir,'analysis'));
opts = fill_section6_defaults(opts, rootDir);
if ~exist(opts.resultDir,'dir'), mkdir(opts.resultDir); end

caseData = build_case33_ehies();
baseScenario = generate_event_chain(caseData, 'storm', struct('seed',opts.seed,'makePlots',true,'resultDir',opts.resultDir));

% 6.1/6.2/6.3: short/medium/long events and functional division.
durationMechanisms = run_duration_mechanism_cases(caseData, baseScenario, opts, [4 12 24]);
functionalDivision = analyze_functional_division(caseData, baseScenario, opts);

% 6.4 Event-chain severity evolution.
severityEvolution = analyze_event_chain_severity(caseData, opts);

% 6.5 Hydrogen-driven restoration reshaping.
restorationReshaping = analyze_restoration_reshaping(caseData, baseScenario, opts);

% 6.6 Resilience-economy tradeoff and ablation studies.
ablation = run_mechanism_ablation_studies(caseData, baseScenario, opts);
economyTradeoff = build_tradeoff_table(ablation);

% Prolonged disaster ablation requested for 2/12/24/48/72/120 h.
prolongedDisaster = run_prolonged_disaster_ablation(caseData, baseScenario, opts);

section6 = struct('caseData',caseData,'baseScenario',baseScenario, ...
    'durationMechanisms',durationMechanisms,'functionalDivision',functionalDivision, ...
    'severityEvolution',severityEvolution,'restorationReshaping',restorationReshaping, ...
    'ablation',ablation,'economyTradeoff',economyTradeoff,'prolongedDisaster',prolongedDisaster);
plot_section6_mechanisms(section6, opts);
writetable(durationMechanisms, fullfile(opts.resultDir,'Section6_multi_timescale_mechanisms.csv'));
writetable(severityEvolution, fullfile(opts.resultDir,'Section6_event_chain_severity.csv'));
writetable(economyTradeoff, fullfile(opts.resultDir,'Section6_resilience_economy_tradeoff.csv'));
save(fullfile(opts.resultDir,'Section6_mechanism_analysis_workspace.mat'), 'section6');
end

function tbl = run_duration_mechanism_cases(baseCaseData, baseScenario, opts, durations)
rows = cell(numel(durations),1);
for i = 1:numel(durations)
    [caseData, scenario] = local_prolong(baseCaseData, baseScenario, durations(i));
    runOpts = opts; runOpts.enableBattery = true; runOpts.enableHydrogen = true; runOpts.enableP2H = true; runOpts.enableH2P = true;
    [res, ~] = solve_resilience_milp(caseData, scenario, runOpts);
    met = compute_resilience_metrics(res, caseData, scenario);
    mech = extract_mechanism_metrics(res, met, caseData, scenario);
    rows{i} = struct('Duration_h',durations(i),'ENS_MWh',mech.ENS,'Critical_ENS_MWh',mech.criticalENS, ...
        'Survivability_h',mech.survivabilityWindow,'RecoverySpeed_pu_per_h',mech.recoverySpeed, ...
        'ResilienceIndex',mech.resilienceIndex,'BatteryContribution_MWh',sum(mech.batteryContribution), ...
        'HydrogenContribution_MWh',sum(mech.hydrogenContribution),'TransitionHour_H2Dominance',mech.temporalTransitionHour, ...
        'PowerOrientedResilience',mech.powerOrientedResilience,'EnergyOrientedResilience',mech.energyOrientedResilience);
end
tbl = struct2table(vertcat(rows{:}));
end

function severityTbl = analyze_event_chain_severity(caseData, opts)
scenarioNames = {'storm','wildfire','ice_disaster'}; rows = cell(numel(scenarioNames),1);
for i = 1:numel(scenarioNames)
    sc = generate_event_chain(caseData, scenarioNames{i}, struct('seed',opts.seed+i,'makePlots',false,'resultDir',opts.resultDir));
    [res, ~] = solve_resilience_milp(caseData, sc, opts);
    met = compute_resilience_metrics(res, caseData, sc);
    severities = [sc.events.severity]; durations = [sc.events.duration];
    rows{i} = struct('Scenario',string(scenarioNames{i}), 'NumEvents',numel(sc.events), ...
        'MeanSeverity',mean(severities), 'SeverityDurationIndex',sum(severities.*durations), ...
        'LineOutageHours',sum(~sc.lineStatus,'all'), 'GridOutageHours',sum(~sc.gridAvailable), ...
        'ResilienceIndex',met.resilienceArea,'ENS_MWh',met.totalENS,'Survivability_h',met.survivabilityHours);
end
severityTbl = struct2table(vertcat(rows{:}));
end

function tradeoff = build_tradeoff_table(ablation)
tbl = ablation.summaryTable;
fields = fieldnames(ablation.results); totalCost = zeros(numel(fields),1);
for i = 1:numel(fields)
    if isfield(ablation.results.(fields{i}), 'objective'), totalCost(i) = ablation.results.(fields{i}).objective; end
end
tradeoff = table(tbl.Case, totalCost, tbl.ResilienceIndex, tbl.ENS_MWh, tbl.HydrogenContribution_MWh, ...
    'VariableNames', {'Case','TotalCost_USD','ResilienceIndex','ENS_MWh','HydrogenContribution_MWh'});
end

function [caseData, scenario] = local_prolong(baseCaseData, baseScenario, duration)
caseData = baseCaseData; T = max(baseCaseData.T, duration + 8); rep = ceil(T/baseCaseData.T);
caseData.T = T;
caseData.Pd = repmat(baseCaseData.Pd,1,rep); caseData.Pd = caseData.Pd(:,1:T);
caseData.gridPrice = repmat(baseCaseData.gridPrice,1,rep); caseData.gridPrice = caseData.gridPrice(1:T);
caseData.pvProfile = repmat(baseCaseData.pvProfile,1,rep); caseData.pvProfile = caseData.pvProfile(1:T);
caseData.wtProfile = repmat(baseCaseData.wtProfile,1,rep); caseData.wtProfile = caseData.wtProfile(1:T);
caseData.h2Demand = repmat(baseCaseData.h2Demand,1,rep); caseData.h2Demand = caseData.h2Demand(1:T);
scenario = baseScenario; firstEvent = 6; endEvent = min(T, firstEvent + duration - 1);
scenario.T = T; scenario.time = 1:T; scenario.name = sprintf('%s_%dh',baseScenario.name,duration);
scenario.stage = repmat("post-event-restoration",1,T); scenario.stage(1:firstEvent-1) = "pre-event"; scenario.stage(firstEvent:endEvent) = "during-event-islanded";
scenario.isPre = scenario.stage=="pre-event"; scenario.isDuring = scenario.stage=="during-event-islanded"; scenario.isPost = scenario.stage=="post-event-restoration";
scenario.gridAvailable = true(1,T); scenario.gridAvailable(firstEvent:endEvent) = false;
scenario.branchAvailableBase = true(caseData.Nl,T); scenario.lineStatus = true(caseData.Nl,T); scenario.faultedLines = baseScenario.faultedLines;
if ~isempty(scenario.faultedLines), scenario.branchAvailableBase(scenario.faultedLines,firstEvent:T) = false; scenario.lineStatus = scenario.branchAvailableBase; end
scenario.pvMultiplier = ones(1,T); scenario.wtMultiplier = ones(1,T); scenario.pvMultiplier(firstEvent:endEvent)=0.45; scenario.wtMultiplier(firstEvent:endEvent)=0.55;
scenario.renewableDerating.pv = scenario.pvMultiplier; scenario.renewableDerating.wt = scenario.wtMultiplier; scenario.busAvailability = true(caseData.Nb,T);
scenario.earliestRepairHour = containers.Map('KeyType','double','ValueType','double'); scenario.faultStartHour = containers.Map('KeyType','double','ValueType','double');
for l = scenario.faultedLines, scenario.faultStartHour(l)=firstEvent; scenario.earliestRepairHour(l)=min(T,endEvent+1); end
end

function opts = fill_section6_defaults(opts, rootDir)
if ~isfield(opts,'solver'), opts.solver = 'gurobi'; end
if ~isfield(opts,'verbose'), opts.verbose = 1; end
if ~isfield(opts,'seed'), opts.seed = 2026; end
if ~isfield(opts,'resultDir'), opts.resultDir = fullfile(rootDir,'results','Section6'); end
if ~isfield(opts,'enableHydrogen'), opts.enableHydrogen = true; end
if ~isfield(opts,'enableBattery'), opts.enableBattery = true; end
if ~isfield(opts,'enableP2H'), opts.enableP2H = true; end
if ~isfield(opts,'enableH2P'), opts.enableH2P = true; end
if ~isfield(opts,'enableMultiStageRestoration'), opts.enableMultiStageRestoration = true; end
if ~isfield(opts,'enableNetworkReconfiguration'), opts.enableNetworkReconfiguration = true; end
if ~isfield(opts,'enableDistributedIslandCoordination'), opts.enableDistributedIslandCoordination = true; end
if ~isfield(opts,'mipGap'), opts.mipGap = 1e-4; end
if ~isfield(opts,'timeLimit'), opts.timeLimit = 1800; end
end
