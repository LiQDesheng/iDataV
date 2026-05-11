function mech = extract_mechanism_metrics(result, metrics, caseData, scenario)
%EXTRACT_MECHANISM_METRICS Extract quantitative Section 6 mechanism indicators.
%
% Inputs:
%   result, metrics - outputs of MILP and compute_resilience_metrics.
%   caseData        - IEEE 33-bus EH-IES data.
%   scenario        - event-chain or prolonged-disaster scenario.
% Output:
%   mech            - mechanism indicators for SCI tables and figures.
%
% Engineering interpretation:
%   Battery contribution is treated as power-oriented resilience because BESS
%   discharge changes fast and absorbs short disturbances. Hydrogen contribution
%   combines fuel-cell output and direct hydrogen demand support, representing
%   energy-oriented resilience under prolonged islanding and restoration.

T = caseData.T; dt = caseData.dt; time = 1:T;
isEvent = scenario.isDuring | scenario.isPost;
criticalMask = false(caseData.Nb,1); criticalMask(scenario.criticalBuses) = true;
criticalDemand = sum(caseData.Pd(criticalMask,:),1) * dt;
criticalServed = max(0, criticalDemand - metrics.criticalENS_t);

batteryEnergy = result.PbDis * dt;
hydrogenElectric = result.Pfc * dt;
hydrogenDirect = result.Hdis * dt;
hydrogenContribution = hydrogenElectric + hydrogenDirect;
totalSupport = batteryEnergy + hydrogenContribution + 1e-9;
hydrogenShare = hydrogenContribution ./ totalSupport;
batteryShare = batteryEnergy ./ totalSupport;
transitionIdx = find(hydrogenShare > batteryShare & isEvent, 1, 'first');
exhaustIdx = find(result.Eb <= 0.15*caseData.bess.Emax & isEvent, 1, 'first');
if isempty(transitionIdx), transitionHour = NaN; else, transitionHour = time(transitionIdx); end
if isempty(exhaustIdx), batteryExhaustHour = NaN; else, batteryExhaustHour = time(exhaustIdx); end
postIdx = find(scenario.isPost);
if numel(postIdx) >= 2
    recoverySpeed = (metrics.compositeServiceLevel(postIdx(end))-metrics.compositeServiceLevel(postIdx(1))) / max(numel(postIdx)-1,1);
else
    recoverySpeed = NaN;
end

mech = struct();
mech.time = time;
mech.serviceLevel = metrics.compositeServiceLevel;
mech.criticalServedRatio = criticalServed ./ max(criticalDemand,1e-9);
mech.survivabilityWindow = metrics.survivabilityHours;
mech.recoverySpeed = recoverySpeed;
mech.recoveryTime = metrics.recoveryTime;
mech.ENS = metrics.totalENS;
mech.criticalENS = metrics.totalCriticalENS;
mech.HENS = metrics.totalHENS;
mech.resilienceIndex = metrics.resilienceArea;
mech.batteryContribution = batteryEnergy;
mech.hydrogenContribution = hydrogenContribution;
mech.fuelCellContribution = hydrogenElectric;
mech.directHydrogenContribution = hydrogenDirect;
mech.batteryShare = batteryShare;
mech.hydrogenShare = hydrogenShare;
mech.temporalTransitionHour = transitionHour;
mech.batteryExhaustHour = batteryExhaustHour;
mech.hydrogenDominanceHours = sum(hydrogenShare > batteryShare & isEvent) * dt;
mech.powerOrientedResilience = sum(batteryEnergy(1:min(T,8))) / max(sum(batteryEnergy),1e-9);
mech.energyOrientedResilience = sum(hydrogenContribution(max(1,T-8):T)) / max(sum(hydrogenContribution),1e-9);
mech.terminalHydrogenSOC = result.Hsto(end) / max(caseData.h2.Hmax,1e-9);
mech.terminalBatterySOC = result.Eb(end) / max(caseData.bess.Emax,1e-9);
end
