function division = analyze_functional_division(caseData, scenario, opts)
%ANALYZE_FUNCTIONAL_DIVISION Quantify BESS/H2 resilience functional division.
%
% Compares battery-only, hydrogen-only, and hybrid battery-hydrogen systems.
% Mechanisms quantified:
%   1) short-term disturbance absorption by battery,
%   2) long-duration survivability by hydrogen storage,
%   3) restoration-stage support from fuel cell and H2 load supply,
%   4) energy supply persistence, and
%   5) dynamic resilience contribution shift: battery -> hydrogen dominance.

if nargin < 3, opts = struct(); end
cases = { ...
    'battery_only', struct('enableBattery',true,  'enableHydrogen',false,'enableP2H',false,'enableH2P',false); ...
    'hydrogen_only',struct('enableBattery',false, 'enableHydrogen',true, 'enableP2H',true, 'enableH2P',true); ...
    'hybrid',       struct('enableBattery',true,  'enableHydrogen',true, 'enableP2H',true, 'enableH2P',true)};

results = struct(); metrics = struct(); mechanisms = struct(); rows = cell(size(cases,1),1);
for i = 1:size(cases,1)
    runOpts = merge_opts(opts, cases{i,2});
    [results.(cases{i,1}), ~] = solve_resilience_milp(caseData, scenario, runOpts);
    metrics.(cases{i,1}) = compute_resilience_metrics(results.(cases{i,1}), caseData, scenario);
    mechanisms.(cases{i,1}) = extract_mechanism_metrics(results.(cases{i,1}), metrics.(cases{i,1}), caseData, scenario);
    rows{i} = compact_row(cases{i,1}, mechanisms.(cases{i,1}));
end
summaryTable = struct2table(vertcat(rows{:}));

division = struct('results',results,'metrics',metrics,'mechanisms',mechanisms,'summaryTable',summaryTable);
if isfield(opts,'resultDir') && ~isempty(opts.resultDir)
    writetable(summaryTable, fullfile(opts.resultDir,'Section6_functional_division_summary.csv'));
    plot_functional_division(division, caseData, scenario, opts.resultDir);
end
end

function row = compact_row(name, mech)
row = struct('Case',string(name),'ENS_MWh',mech.ENS,'Critical_ENS_MWh',mech.criticalENS, ...
    'Survivability_h',mech.survivabilityWindow,'RecoverySpeed_pu_per_h',mech.recoverySpeed, ...
    'RecoveryTime_h',mech.recoveryTime,'ResilienceIndex',mech.resilienceIndex, ...
    'BatteryExhaustHour',mech.batteryExhaustHour,'TransitionHour_H2Dominance',mech.temporalTransitionHour, ...
    'HydrogenDominanceHours',mech.hydrogenDominanceHours);
end

function opts = merge_opts(base, patch)
opts = base; f = fieldnames(patch); for k = 1:numel(f), opts.(f{k}) = patch.(f{k}); end
end
