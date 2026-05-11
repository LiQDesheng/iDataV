function [result, modelInfo] = solve_resilience_milp(caseData, scenario, opts)
%SOLVE_RESILIENCE_MILP Solve resilience-oriented EH-IES scheduling MILP.
%
% Inputs:
%   caseData - network, load, device, and cost data.
%   scenario - event-chain scenario data.
%   opts     - solver switches and study options.
% Outputs:
%   result   - optimized schedules and restoration decisions.
%   modelInfo- YALMIP diagnostics and model dimensions.
%
% Core MILP formulation:
%   min energy procurement + weighted ENS + H2-ENS + switching/repair costs
%       - terminal storage value
%   s.t. nodal electric balance, aggregate hydrogen balance, storage dynamics,
%        islanding, line availability, switchable radiality, repair sequencing,
%        converter limits, and resilience reserve constraints.

arguments
    caseData struct
    scenario struct
    opts struct
end

opts = fill_default_solver_options(opts);
Nb = caseData.Nb; Nl = caseData.Nl; T = caseData.T; dt = caseData.dt;
from = caseData.branch(:,1); to = caseData.branch(:,2);

%% Decision variables
Pgrid = sdpvar(1,T,'full');
Pflow = sdpvar(Nl,T,'full');
ysw = binvar(Nl,T,'full');
zbus = binvar(Nb,T,'full');
Pshed = sdpvar(Nb,T,'full');
Ppv = sdpvar(numel(caseData.pvBus),T,'full');
Pwt = sdpvar(numel(caseData.wtBus),T,'full');
PbCh = sdpvar(1,T,'full'); PbDis = sdpvar(1,T,'full'); Eb = sdpvar(1,T,'full');
Pel = sdpvar(1,T,'full'); Hprod = sdpvar(1,T,'full');
Pfc = sdpvar(1,T,'full'); Hfc = sdpvar(1,T,'full');
Hdis = sdpvar(1,T,'full'); Hsto = sdpvar(1,T,'full'); Hshed = sdpvar(1,T,'full');
repaired = binvar(Nl,T,'full');
repairAction = binvar(Nl,T,'full');
switchAction = sdpvar(Nl,T,'full');

Con = [];
Objective = 0;

%% Static bounds and initial statuses
Con = [Con, Pgrid >= 0, Pgrid <= caseData.gridImportMax * scenario.gridAvailable];
Con = [Con, Pshed >= 0, Pshed <= caseData.Pd];
Con = [Con, PbCh >= 0, PbCh <= caseData.bess.Pmax * opts.enableBattery, ...
            PbDis >= 0, PbDis <= caseData.bess.Pmax * opts.enableBattery, ...
            0 <= Eb <= caseData.bess.Emax * opts.enableBattery];
Con = [Con, Pel >= 0, Pel <= caseData.el.Pmax * opts.enableHydrogen * opts.enableP2H, Hprod == caseData.el.eta * Pel];
Con = [Con, Pfc >= 0, Pfc <= caseData.fc.Pmax * opts.enableHydrogen * opts.enableH2P, Hfc == Pfc / max(caseData.fc.eta,1e-6)];
Con = [Con, Hdis >= 0, Hsto >= 0, Hsto <= caseData.h2.Hmax * opts.enableHydrogen, Hshed >= 0, Hshed <= caseData.h2Demand];
if isfield(scenario,'busAvailability')
    busAvailability = scenario.busAvailability;
else
    busAvailability = true(Nb,T);
end
Con = [Con, -caseData.lineCap * ones(1,T) <= Pflow <= caseData.lineCap * ones(1,T)];

for g = 1:numel(caseData.pvBus)
    ub = caseData.pvCap(g) * caseData.pvProfile .* scenario.pvMultiplier;
    Con = [Con, 0 <= Ppv(g,:) <= ub]; %#ok<AGROW>
end
for g = 1:numel(caseData.wtBus)
    ub = caseData.wtCap(g) * caseData.wtProfile .* scenario.wtMultiplier;
    Con = [Con, 0 <= Pwt(g,:) <= ub]; %#ok<AGROW>
end

%% Time-coupled constraints
for t = 1:T
    % Electric storage dynamics: short-term absorption and ride-through.
    if t == 1
        Con = [Con, Eb(t) == opts.enableBattery*caseData.bess.E0 + dt*(caseData.bess.etaCh*PbCh(t) - PbDis(t)/caseData.bess.etaDis)]; %#ok<AGROW>
        Con = [Con, Hsto(t) == opts.enableHydrogen*caseData.h2.H0 + dt*(caseData.h2.etaCh*Hprod(t) - (Hfc(t)+Hdis(t))/caseData.h2.etaDis)]; %#ok<AGROW>
    else
        Con = [Con, Eb(t) == Eb(t-1) + dt*(caseData.bess.etaCh*PbCh(t) - PbDis(t)/caseData.bess.etaDis)]; %#ok<AGROW>
        Con = [Con, Hsto(t) == Hsto(t-1) + dt*(caseData.h2.etaCh*Hprod(t) - (Hfc(t)+Hdis(t))/caseData.h2.etaDis)]; %#ok<AGROW>
        Con = [Con, switchAction(:,t) >= ysw(:,t) - ysw(:,t-1), switchAction(:,t) >= ysw(:,t-1) - ysw(:,t)]; %#ok<AGROW>
    end

    % Resilience reserve preparation at the last pre-event hour.
    if t == find(scenario.isPre,1,'last')
        Con = [Con, Hsto(t) >= scenario.minH2ReserveAtEvent * opts.enableHydrogen * opts.enableP2H, ...
                    Eb(t) >= scenario.minBessReserveAtEvent * opts.enableBattery]; %#ok<AGROW>
    end

    % Branch operational status: energized switch requires available/repaired line.
    for l = 1:Nl
        if ismember(l, scenario.faultedLines)
            if isfield(scenario,'faultStartHour') && isKey(scenario.faultStartHour,l)
                faultStart = scenario.faultStartHour(l);
            else
                faultStart = 1;
            end
            if t < faultStart
                Con = [Con, repaired(l,t) == 1, repairAction(l,t) == 0]; %#ok<AGROW> pre-event availability
            elseif t < scenario.earliestRepairHour(l)
                Con = [Con, repaired(l,t) == 0, repairAction(l,t) == 0]; %#ok<AGROW>
            elseif t == 1
                Con = [Con, repaired(l,t) == repairAction(l,t)]; %#ok<AGROW>
            else
                Con = [Con, repaired(l,t) >= repaired(l,t-1), repaired(l,t) <= repaired(l,t-1) + repairAction(l,t)]; %#ok<AGROW>
            end
            Con = [Con, ysw(l,t) <= repaired(l,t)]; %#ok<AGROW>
        else
            Con = [Con, repaired(l,t) == 1, repairAction(l,t) == 0, ysw(l,t) <= scenario.branchAvailableBase(l,t)]; %#ok<AGROW>
        end
        Con = [Con, -caseData.lineCap(l)*ysw(l,t) <= Pflow(l,t) <= caseData.lineCap(l)*ysw(l,t)]; %#ok<AGROW>
        Con = [Con, ysw(l,t) <= zbus(from(l),t), ysw(l,t) <= zbus(to(l),t)]; %#ok<AGROW>
        if ~opts.enableNetworkReconfiguration
            if caseData.normallyClosed(l)
                if ismember(l, scenario.faultedLines)
                    Con = [Con, ysw(l,t) == repaired(l,t)]; %#ok<AGROW>
                else
                    Con = [Con, ysw(l,t) == scenario.branchAvailableBase(l,t)]; %#ok<AGROW>
                end
            else
                Con = [Con, ysw(l,t) == 0]; %#ok<AGROW>
            end
        end
    end

    if opts.enableMultiStageRestoration
        Con = [Con, sum(repairAction(:,t)) <= caseData.maxRepairsPerHour * scenario.isPost(t)]; %#ok<AGROW>
    else
        Con = [Con, sum(repairAction(:,t)) == 0]; %#ok<AGROW>
    end

    % Radial energized topology relaxation: no more closed branches than energized buses minus one.
    Con = [Con, zbus <= busAvailability]; %#ok<AGROW>
    Con = [Con, zbus(caseData.slackBus,t) == scenario.gridAvailable(t)]; %#ok<AGROW>
    if opts.enableDistributedIslandCoordination
        Con = [Con, zbus(caseData.fc.bus,t) >= Pfc(t)/max(caseData.fc.Pmax,1e-6)]; %#ok<AGROW> fuel-cell black-start island
    else
        Con = [Con, Pfc(t) <= caseData.fc.Pmax * scenario.gridAvailable(t)]; %#ok<AGROW> no distributed island black-start
    end
    Con = [Con, sum(ysw(:,t)) <= max(0,Nb-1)]; %#ok<AGROW>
    Con = [Con, sum(ysw(:,t)) <= sum(zbus(:,t)) - zbus(caseData.slackBus,t) + scenario.gridAvailable(t)]; %#ok<AGROW>

    % Nodal electric balance.
    for b = 1:Nb
        inj = 0;
        if b == caseData.slackBus, inj = inj + Pgrid(t); end
        inj = inj + sum(Ppv(caseData.pvBus == b,t)) + sum(Pwt(caseData.wtBus == b,t));
        if b == caseData.bess.bus, inj = inj + PbDis(t) - PbCh(t); end
        if b == caseData.el.bus, inj = inj - Pel(t); end
        if b == caseData.fc.bus, inj = inj + Pfc(t); end
        netOut = sum(Pflow(from == b,t)) - sum(Pflow(to == b,t));
        Con = [Con, inj + Pshed(b,t) - caseData.Pd(b,t) == netOut]; %#ok<AGROW>
        Con = [Con, Pshed(b,t) >= caseData.Pd(b,t) * (1 - zbus(b,t))]; %#ok<AGROW>
    end

    % Hydrogen balance: long-duration conversion, storage, and mobility demand support.
    Con = [Con, Hdis(t) + Hshed(t) == caseData.h2Demand(t)]; %#ok<AGROW>
    if opts.limitElectrolyzerRamping && t > 1
        Con = [Con, -opts.electrolyzerRampRate*caseData.el.Pmax <= Pel(t)-Pel(t-1) <= opts.electrolyzerRampRate*caseData.el.Pmax]; %#ok<AGROW>
    end

    % Objective components.
    weightedENS = caseData.loadPriority' * Pshed(:,t);
    Objective = Objective + dt*(caseData.gridPrice(t)*Pgrid(t) + caseData.curtailPenalty*weightedENS + caseData.h2ShedPenalty*Hshed(t));
    Objective = Objective + caseData.switchCost*sum(switchAction(:,t)) + caseData.repairCost*sum(repairAction(:,t));
end

% Terminal value rewards recovery readiness after the event chain.
Objective = Objective - caseData.h2TerminalValue*Hsto(T) - caseData.batteryTerminalValue*Eb(T);

%% Solver configuration
ops = sdpsettings('solver', opts.solver, 'verbose', opts.verbose, 'cachesolvers', 1);
if strcmpi(opts.solver,'gurobi')
    ops.gurobi.MIPGap = opts.mipGap; ops.gurobi.TimeLimit = opts.timeLimit;
elseif strcmpi(opts.solver,'cplex')
    ops.cplex.mip.tolerances.mipgap = opts.mipGap; ops.cplex.timelimit = opts.timeLimit;
end

diagnostics = optimize(Con, Objective, ops);
if diagnostics.problem ~= 0
    warning('EHIES:OptimizationStatus','YALMIP returned status %d: %s', diagnostics.problem, diagnostics.info);
end

%% Pack results
result = struct();
vars = {'Pgrid','Pflow','ysw','zbus','Pshed','Ppv','Pwt','PbCh','PbDis','Eb','Pel','Hprod','Pfc','Hfc','Hdis','Hsto','Hshed','repaired','repairAction','switchAction'};
for i = 1:numel(vars)
    result.(vars{i}) = value(eval(vars{i}));
end
result.objective = value(Objective);
result.status = diagnostics.problem;
result.info = diagnostics.info;
result.objectiveBreakdown = compute_objective_breakdown(result, caseData, scenario, opts);
result.time = 1:T;
result.stage = scenario.stage;

modelInfo = struct();
modelInfo.diagnostics = diagnostics;
modelInfo.numConstraints = length(Con);
modelInfo.numBuses = Nb;
modelInfo.numBranches = Nl;
modelInfo.hydrogenEnabled = opts.enableHydrogen;
modelInfo.batteryEnabled = opts.enableBattery;
modelInfo.p2hEnabled = opts.enableP2H;
modelInfo.h2pEnabled = opts.enableH2P;
modelInfo.multiStageRestoration = opts.enableMultiStageRestoration;
modelInfo.networkReconfiguration = opts.enableNetworkReconfiguration;
end

function opts = fill_default_solver_options(opts)
%FILL_DEFAULT_SOLVER_OPTIONS Ensure modular runners can call the MILP safely.
if ~isfield(opts,'solver'), opts.solver = 'gurobi'; end
if ~isfield(opts,'verbose'), opts.verbose = 1; end
if ~isfield(opts,'enableHydrogen'), opts.enableHydrogen = true; end
if ~isfield(opts,'enableBattery'), opts.enableBattery = true; end
if ~isfield(opts,'enableP2H'), opts.enableP2H = true; end
if ~isfield(opts,'enableH2P'), opts.enableH2P = true; end
if ~isfield(opts,'enableDistributedIslandCoordination'), opts.enableDistributedIslandCoordination = true; end
if ~isfield(opts,'limitElectrolyzerRamping'), opts.limitElectrolyzerRamping = false; end
if ~isfield(opts,'electrolyzerRampRate'), opts.electrolyzerRampRate = 0.20; end
if ~isfield(opts,'enableMultiStageRestoration'), opts.enableMultiStageRestoration = true; end
if ~isfield(opts,'enableNetworkReconfiguration'), opts.enableNetworkReconfiguration = true; end
if ~isfield(opts,'mipGap'), opts.mipGap = 1e-4; end
if ~isfield(opts,'timeLimit'), opts.timeLimit = 1800; end
end

function breakdown = compute_objective_breakdown(result, caseData, scenario, opts)
%COMPUTE_OBJECTIVE_BREAKDOWN Report economic terms for tables in Section 5.
dt = caseData.dt;
breakdown.gridCost = sum(dt * caseData.gridPrice .* result.Pgrid);
breakdown.weightedENSCost = sum(dt * caseData.curtailPenalty * (caseData.loadPriority' * result.Pshed));
breakdown.hydrogenShedCost = sum(dt * caseData.h2ShedPenalty * result.Hshed);
breakdown.switchingCost = caseData.switchCost * sum(result.switchAction(:));
breakdown.repairCost = caseData.repairCost * sum(result.repairAction(:));
breakdown.terminalCredit = caseData.h2TerminalValue*result.Hsto(end) + caseData.batteryTerminalValue*result.Eb(end);
breakdown.hydrogenEnabled = opts.enableHydrogen;
breakdown.eventName = scenario.name;
end
