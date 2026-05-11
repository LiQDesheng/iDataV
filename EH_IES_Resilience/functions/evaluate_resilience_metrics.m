function assessment = evaluate_resilience_metrics(resultSet, caseData, scenarioSet)
%EVALUATE_RESILIENCE_METRICS Section 5.8 comprehensive resilience assessment.
%
% Inputs:
%   resultSet   - struct whose fields are scenario/case names and values are MILP results.
%   caseData    - IEEE 33-bus EH-IES data.
%   scenarioSet - struct with matching scenario/event-chain fields.
% Output:
%   assessment  - metrics by case, summary table, and normalized radar matrix.
%
% Indicators:
%   ENS, weighted ENS, critical ENS, HENS, resilience-area index, survivability
%   hours, recovery time, H2 fuel-cell contribution, and terminal storage reserve.

names = fieldnames(resultSet);
metricsByCase = struct();
rows = cell(numel(names),1);
for i = 1:numel(names)
    nm = names{i};
    metricsByCase.(nm) = compute_resilience_metrics(resultSet.(nm), caseData, scenarioSet.(nm));
    rows{i} = metricsByCase.(nm).summary;
end
summaryTable = struct2table(vertcat(rows{:}));
summaryTable.Case = string(names);
summaryTable = movevars(summaryTable, 'Case', 'Before', 1);

% Larger-is-better normalized radar data for publication tables/figures.
radarIndicators = {'Resilience_Area','Survivability_h','Minimum_Islanded_Service','H2_FuelCell_Energy_MWh','H2_Terminal_SOC'};
radarMatrix = zeros(height(summaryTable), numel(radarIndicators));
for j = 1:numel(radarIndicators)
    v = summaryTable.(radarIndicators{j});
    radarMatrix(:,j) = (v - min(v)) ./ max(max(v)-min(v), 1e-9);
end
assessment = struct();
assessment.metricsByCase = metricsByCase;
assessment.summaryTable = summaryTable;
assessment.radarIndicators = radarIndicators;
assessment.radarMatrix = radarMatrix;
end
