function studyTable = run_ablation_studies(caseData, scenario, baseOpts)
%RUN_ABLATION_STUDIES Execute hydrogen/restoration ablation experiments.
%
% Inputs:
%   caseData - EH-IES test system.
%   scenario - event-chain scenario.
%   baseOpts - base solver options.
% Output:
%   studyTable - table comparing objective, ENS, HENS, resilience area, and
%                survivability across mechanisms.
%
% Scientific use:
%   This routine directly supports ablation-study tables demonstrating whether
%   hydrogen storage, multi-stage restoration, and network reconfiguration change
%   survivability and recovery performance.

cases = {
    'Full_H2_MultiStage_Reconfig', true,  true,  true;
    'No_Hydrogen',                false, true,  true;
    'SingleStage_Restoration',    true,  false, true;
    'No_Reconfiguration',         true,  true,  false};

records = cell(size(cases,1),1);
for i = 1:size(cases,1)
    opts = baseOpts;
    opts.caseName = cases{i,1};
    opts.enableHydrogen = cases{i,2};
    opts.enableMultiStageRestoration = cases{i,3};
    opts.enableNetworkReconfiguration = cases{i,4};
    [res, ~] = solve_resilience_milp(caseData, scenario, opts);
    met = compute_resilience_metrics(res, caseData, scenario);
    records{i} = met.summary;
end

studyTable = struct2table(vertcat(records{:}));
studyTable.Case = string(cases(:,1));
studyTable = movevars(studyTable, 'Case', 'Before', 1);
if isfield(baseOpts,'resultDir') && ~isempty(baseOpts.resultDir)
    writetable(studyTable, fullfile(baseOpts.resultDir, 'ablation_study_summary.csv'));
end
end
