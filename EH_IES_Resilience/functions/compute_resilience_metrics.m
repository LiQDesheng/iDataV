function metrics = compute_resilience_metrics(result, caseData, scenario)
%COMPUTE_RESILIENCE_METRICS Evaluate EH-IES resilience performance.
%
% Inputs:
%   result   - optimizer output from solve_resilience_milp.
%   caseData - system data.
%   scenario - event-chain data.
% Output:
%   metrics  - resilience curves, ENS/HENS, survivability and recovery indices.
%
% Mathematical meaning:
%   Service level is 1 - unserved demand / total demand. The resilience trapezoid
%   is approximated by the normalized area under the service-level curve. Hydrogen
%   value is revealed by H2 storage trajectories, H2-supported fuel-cell energy,
%   and the survivability window under islanded operation.

T = caseData.T; dt = caseData.dt;
loadTotal = sum(caseData.Pd,1);
criticalMask = false(caseData.Nb,1); criticalMask(scenario.criticalBuses) = true;
criticalLoad = sum(caseData.Pd(criticalMask,:),1);

ENS_t = sum(result.Pshed,1) * dt;
weightedENS_t = caseData.loadPriority' * result.Pshed * dt;
criticalENS_t = sum(result.Pshed(criticalMask,:),1) * dt;
HENS_t = result.Hshed * dt;

serviceLevel = max(0, 1 - ENS_t ./ max(loadTotal*dt,1e-9));
criticalServiceLevel = max(0, 1 - criticalENS_t ./ max(criticalLoad*dt,1e-9));
h2ServiceLevel = max(0, 1 - HENS_t ./ max(caseData.h2Demand*dt,1e-9));
h2ServiceLevel(caseData.h2Demand <= 1e-9) = 1;

metrics = struct();
metrics.time = 1:T;
metrics.ENS_t = ENS_t;
metrics.weightedENS_t = weightedENS_t;
metrics.criticalENS_t = criticalENS_t;
metrics.HENS_t = HENS_t;
metrics.serviceLevel = serviceLevel;
metrics.criticalServiceLevel = criticalServiceLevel;
metrics.h2ServiceLevel = h2ServiceLevel;
metrics.compositeServiceLevel = 0.55*serviceLevel + 0.30*criticalServiceLevel + 0.15*h2ServiceLevel;
metrics.resilienceArea = trapz(metrics.time, metrics.compositeServiceLevel) / (T-1);

isIsland = scenario.isDuring | (scenario.isPost & ~scenario.gridAvailable);
servedRatioIsland = serviceLevel(isIsland);
metrics.survivabilityHours = sum(servedRatioIsland >= 0.90) * dt;
metrics.minimumIslandedService = min(servedRatioIsland);
metrics.totalENS = sum(ENS_t);
metrics.totalWeightedENS = sum(weightedENS_t);
metrics.totalCriticalENS = sum(criticalENS_t);
metrics.totalHENS = sum(HENS_t);
metrics.h2FuelCellEnergy = sum(result.Pfc) * dt;
metrics.h2TerminalSOC = result.Hsto(end) / max(caseData.h2.Hmax,1e-9);
metrics.bessTerminalSOC = result.Eb(end) / max(caseData.bess.Emax,1e-9);

% Recovery time: first post-event hour when composite service exceeds 98%.
postIdx = find(scenario.isPost);
recIdx = postIdx(find(metrics.compositeServiceLevel(postIdx) >= 0.98, 1, 'first'));
if isempty(recIdx)
    metrics.recoveryTime = NaN;
else
    metrics.recoveryTime = recIdx - postIdx(1) + 1;
end

metrics.summary = struct();
metrics.summary.Objective_USD = result.objective;
metrics.summary.Total_ENS_MWh = metrics.totalENS;
metrics.summary.Weighted_ENS_MWh = metrics.totalWeightedENS;
metrics.summary.Critical_ENS_MWh = metrics.totalCriticalENS;
metrics.summary.Hydrogen_ENS_MWh = metrics.totalHENS;
metrics.summary.Resilience_Area = metrics.resilienceArea;
metrics.summary.Survivability_h = metrics.survivabilityHours;
metrics.summary.Minimum_Islanded_Service = metrics.minimumIslandedService;
metrics.summary.H2_FuelCell_Energy_MWh = metrics.h2FuelCellEnergy;
metrics.summary.H2_Terminal_SOC = metrics.h2TerminalSOC;
metrics.summary.BESS_Terminal_SOC = metrics.bessTerminalSOC;
metrics.summary.Recovery_Time_h = metrics.recoveryTime;
end
