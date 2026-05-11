function prolonged = run_prolonged_disaster_ablation(baseCaseData, baseScenario, opts)
%RUN_PROLONGED_DISASTER_ABLATION Prolonged-disaster Section 6 experiment.
%
% Simulates disaster durations: 2, 12, 24, 48, 72, and 120 h.
% Compares battery-only and hydrogen-enabled systems and identifies resilience
% collapse threshold, battery exhaustion point, temporal transition point, and
% hydrogen dominance interval.

if nargin < 3, opts = struct(); end
durations = [2 12 24 48 72 120];
rows = {}; resultMap = struct();
for d = durations
    [caseData, scenario] = prolong_case_and_scenario(baseCaseData, baseScenario, d);
    for mode = ["battery_only", "hydrogen_enabled"]
        runOpts = opts;
        if mode == "battery_only"
            runOpts.enableBattery = true; runOpts.enableHydrogen = false; runOpts.enableP2H = false; runOpts.enableH2P = false;
        else
            runOpts.enableBattery = true; runOpts.enableHydrogen = true; runOpts.enableP2H = true; runOpts.enableH2P = true;
        end
        [res, ~] = solve_resilience_milp(caseData, scenario, runOpts);
        met = compute_resilience_metrics(res, caseData, scenario);
        mech = extract_mechanism_metrics(res, met, caseData, scenario);
        key = sprintf('%s_%dh', char(mode), d);
        resultMap.(key) = struct('caseData',caseData,'scenario',scenario,'result',res,'metrics',met,'mechanism',mech);
        rows{end+1,1} = struct('Duration_h',d,'Mode',mode,'ENS_MWh',mech.ENS, ... %#ok<AGROW>
            'ResilienceIndex',mech.resilienceIndex,'Survivability_h',mech.survivabilityWindow, ...
            'BatteryExhaustHour',mech.batteryExhaustHour,'TransitionHour_H2Dominance',mech.temporalTransitionHour, ...
            'HydrogenDominanceHours',mech.hydrogenDominanceHours,'HydrogenContribution_MWh',sum(mech.hydrogenContribution));
    end
end
summaryTable = struct2table(vertcat(rows{:}));
prolonged = struct('summaryTable',summaryTable,'cases',resultMap);
prolonged.collapseThreshold_h = detect_collapse(summaryTable);
prolonged.transitionPoint_h = detect_transition(summaryTable);
if isfield(opts,'resultDir') && ~isempty(opts.resultDir)
    writetable(summaryTable, fullfile(opts.resultDir,'Section6_prolonged_disaster_ablation.csv'));
    plot_prolonged_disaster(prolonged, opts.resultDir);
end
end

function [caseData, scenario] = prolong_case_and_scenario(baseCaseData, baseScenario, duration)
caseData = baseCaseData; T = max(24, duration + 8); rep = ceil(T/baseCaseData.T);
caseData.T = T;
caseData.Pd = repmat(baseCaseData.Pd,1,rep); caseData.Pd = caseData.Pd(:,1:T);
caseData.gridPrice = repmat(baseCaseData.gridPrice,1,rep); caseData.gridPrice = caseData.gridPrice(1:T);
caseData.pvProfile = repmat(baseCaseData.pvProfile,1,rep); caseData.pvProfile = caseData.pvProfile(1:T);
caseData.wtProfile = repmat(baseCaseData.wtProfile,1,rep); caseData.wtProfile = caseData.wtProfile(1:T);
caseData.h2Demand = repmat(baseCaseData.h2Demand,1,rep); caseData.h2Demand = caseData.h2Demand(1:T);
scenario = baseScenario; scenario.T = T; scenario.time = 1:T; firstEvent = 6; endEvent = min(T, firstEvent + duration - 1);
scenario.name = sprintf('%s_%dh', baseScenario.name, duration);
scenario.stage = repmat("post-event-restoration",1,T); scenario.stage(1:firstEvent-1) = "pre-event"; scenario.stage(firstEvent:endEvent) = "during-event-islanded";
scenario.isPre = scenario.stage == "pre-event"; scenario.isDuring = scenario.stage == "during-event-islanded"; scenario.isPost = scenario.stage == "post-event-restoration";
scenario.gridAvailable = true(1,T); scenario.gridAvailable(firstEvent:endEvent) = false;
scenario.branchAvailableBase = true(caseData.Nl,T); scenario.lineStatus = true(caseData.Nl,T);
scenario.faultedLines = baseScenario.faultedLines;
if ~isempty(scenario.faultedLines)
    scenario.branchAvailableBase(scenario.faultedLines, firstEvent:T) = false; scenario.lineStatus = scenario.branchAvailableBase;
end
scenario.pvMultiplier = ones(1,T); scenario.wtMultiplier = ones(1,T);
scenario.pvMultiplier(firstEvent:endEvent) = 0.45; scenario.wtMultiplier(firstEvent:endEvent) = 0.55;
scenario.renewableDerating.pv = scenario.pvMultiplier; scenario.renewableDerating.wt = scenario.wtMultiplier;
scenario.busAvailability = true(caseData.Nb,T);
scenario.earliestRepairHour = containers.Map('KeyType','double','ValueType','double'); scenario.faultStartHour = containers.Map('KeyType','double','ValueType','double');
for l = scenario.faultedLines, scenario.faultStartHour(l) = firstEvent; scenario.earliestRepairHour(l) = min(T,endEvent+1); end
scenario.minH2ReserveAtEvent = 0.65 * caseData.h2.Hmax; scenario.minBessReserveAtEvent = 0.55 * caseData.bess.Emax;
end

function h = detect_collapse(tbl)
idx = tbl.ResilienceIndex < 0.6;
if any(idx), h = min(tbl.Duration_h(idx)); else, h = NaN; end
end
function h = detect_transition(tbl)
h2 = tbl(tbl.Mode=="hydrogen_enabled",:); idx = find(h2.HydrogenDominanceHours > 0,1,'first'); if isempty(idx), h = NaN; else, h = h2.Duration_h(idx); end
end
