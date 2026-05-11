function [baseline, metrics, normalScenario] = run_baseline_operation(caseData, opts)
%RUN_BASELINE_OPERATION Section 5.2 baseline normal operation.
%
% Inputs:
%   caseData - IEEE 33-bus EH-IES test system.
%   opts     - solver options shared with resilience modules.
% Outputs:
%   baseline       - normal-operation dispatch result.
%   metrics        - baseline ENS/SOC/economic metrics.
%   normalScenario - no-disaster scenario structure compatible with MILP.
%
% Optimization structure:
%   The same EH-IES MILP is solved with all lines/grid available and all RES
%   derating factors equal to 1. This creates the reference trajectory used in
%   Section 5.2 and for resilience-degradation comparisons in Section 5.8.

if nargin < 2, opts = struct(); end
normalScenario = create_normal_scenario(caseData);
baseOpts = opts;
baseOpts.enableHydrogen = get_opt(opts, 'enableHydrogen', true);
baseOpts.enableMultiStageRestoration = false;
baseOpts.enableNetworkReconfiguration = false;
[baseline, ~] = solve_resilience_milp(caseData, normalScenario, baseOpts);
metrics = compute_resilience_metrics(baseline, caseData, normalScenario);
end

function scenario = create_normal_scenario(caseData)
T = caseData.T;
scenario = struct();
scenario.name = 'baseline_normal_operation';
scenario.description = 'Normal grid-connected operation without event-chain disturbances.';
scenario.T = T; scenario.time = 1:T;
scenario.stage = repmat("pre-event",1,T);
scenario.isPre = true(1,T); scenario.isDuring = false(1,T); scenario.isPost = false(1,T);
scenario.gridAvailable = true(1,T);
scenario.branchAvailableBase = true(caseData.Nl,T);
scenario.lineStatus = scenario.branchAvailableBase;
scenario.busAvailability = true(caseData.Nb,T);
scenario.pvMultiplier = ones(1,T); scenario.wtMultiplier = ones(1,T);
scenario.renewableDerating.pv = scenario.pvMultiplier;
scenario.renewableDerating.wt = scenario.wtMultiplier;
scenario.faultedLines = [];
scenario.earliestRepairHour = containers.Map('KeyType','double','ValueType','double');
scenario.faultStartHour = containers.Map('KeyType','double','ValueType','double');
scenario.criticalBuses = [6 18 25 30 33];
scenario.minH2ReserveAtEvent = 0;
scenario.minBessReserveAtEvent = 0;
scenario.islandInfo = cell(1,T);
for t = 1:T
    scenario.islandInfo{t} = struct('id',1,'buses',1:caseData.Nb,'hasGrid',true,'hasHydrogenHub',true,'hasBlackStart',true);
end
end

function v = get_opt(opts, name, defaultValue)
if isfield(opts,name), v = opts.(name); else, v = defaultValue; end
end
