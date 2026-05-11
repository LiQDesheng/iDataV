function ablation = run_mechanism_ablation_studies(caseData, scenario, opts)
%RUN_MECHANISM_ABLATION_STUDIES Controlled Section 6 ablation experiments.
%
% Ablation cases:
%   1 remove H2 storage, 2 disable H2P, 3 disable P2H pre-charging,
%   4 remove multi-stage restoration, 5 remove network reconfiguration,
%   6 battery-only, 7 limit electrolyzer ramping, 8 remove distributed island coordination.

if nargin < 3, opts = struct(); end
caseDefs = { ...
    'Full_Model', struct(); ...
    'Remove_H2_Storage', struct('enableHydrogen',false,'enableP2H',false,'enableH2P',false); ...
    'Disable_H2P', struct('enableHydrogen',true,'enableH2P',false); ...
    'Disable_P2H_Precharging', struct('enableHydrogen',true,'enableP2H',false); ...
    'No_MultiStage_Restoration', struct('enableMultiStageRestoration',false); ...
    'No_Network_Reconfiguration', struct('enableNetworkReconfiguration',false); ...
    'Battery_Only', struct('enableBattery',true,'enableHydrogen',false,'enableP2H',false,'enableH2P',false); ...
    'Limited_Electrolyzer_Ramping', struct('limitElectrolyzerRamping',true,'electrolyzerRampRate',0.08); ...
    'No_Distributed_Island_Coordination', struct('enableDistributedIslandCoordination',false)};

results = struct(); metrics = struct(); mechanisms = struct(); rows = cell(size(caseDefs,1),1);
for i = 1:size(caseDefs,1)
    nm = matlab.lang.makeValidName(caseDefs{i,1});
    runOpts = merge_opts(opts, caseDefs{i,2});
    [results.(nm), ~] = solve_resilience_milp(caseData, scenario, runOpts);
    metrics.(nm) = compute_resilience_metrics(results.(nm), caseData, scenario);
    mechanisms.(nm) = extract_mechanism_metrics(results.(nm), metrics.(nm), caseData, scenario);
    rows{i} = struct('Case',string(caseDefs{i,1}), 'ENS_MWh',mechanisms.(nm).ENS, ...
        'CriticalLoadRatio', mean(mechanisms.(nm).criticalServedRatio), ...
        'ResilienceIndex', mechanisms.(nm).resilienceIndex, ...
        'RecoveryTime_h', mechanisms.(nm).recoveryTime, ...
        'Survivability_h', mechanisms.(nm).survivabilityWindow, ...
        'HydrogenContribution_MWh', sum(mechanisms.(nm).hydrogenContribution), ...
        'BatteryContribution_MWh', sum(mechanisms.(nm).batteryContribution));
end
summaryTable = struct2table(vertcat(rows{:}));
baseENS = summaryTable.ENS_MWh(1); baseRI = summaryTable.ResilienceIndex(1);
summaryTable.ENS_Degradation_pct = 100*(summaryTable.ENS_MWh - baseENS)/max(baseENS,1e-9);
summaryTable.RI_Degradation_pct = 100*(baseRI - summaryTable.ResilienceIndex)/max(baseRI,1e-9);

ablation = struct('results',results,'metrics',metrics,'mechanisms',mechanisms,'summaryTable',summaryTable);
if isfield(opts,'resultDir') && ~isempty(opts.resultDir)
    writetable(summaryTable, fullfile(opts.resultDir,'Section6_mechanism_ablation_summary.csv'));
    plot_ablation_results(ablation, opts.resultDir);
end
end

function opts = merge_opts(base, patch)
opts = base; f = fieldnames(patch); for k = 1:numel(f), opts.(f{k}) = patch.(f{k}); end
end
