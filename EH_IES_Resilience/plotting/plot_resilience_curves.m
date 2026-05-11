function plot_resilience_curves(resultSet, metricSet, caseData, scenarioSet, opts)
%PLOT_RESILIENCE_CURVES Section 5 publication-quality figure generator.
%
% Inputs:
%   resultSet   - struct of optimization results.
%   metricSet   - struct of metrics; each field may be output of compute_*.
%   caseData    - IEEE 33-bus EH-IES data.
%   scenarioSet - matching scenario/event-chain data.
%   opts        - .resultDir output directory.
% Outputs:
%   Figures for resilience curves, ENS, restoration trajectory, SOC/SOHC,
%   hydrogen storage evolution and critical-load restoration.

if nargin < 5, opts = struct(); end
if ~isfield(opts,'resultDir') || isempty(opts.resultDir), opts.resultDir = fullfile(pwd,'results'); end
if ~exist(opts.resultDir,'dir'), mkdir(opts.resultDir); end
set(groot, 'defaultAxesFontName', 'Times New Roman', 'defaultTextFontName', 'Times New Roman');
set(groot, 'defaultAxesFontSize', 11, 'defaultLineLineWidth', 2.0);

names = fieldnames(resultSet);
colors = lines(numel(names));
T = caseData.T; t = 1:T;

fig = figure('Name','Section 5 Resilience Curves','Color','w','Position',[80 80 950 520]); hold on;
for i = 1:numel(names)
    m = unpack_metric(metricSet, names{i});
    plot(t, m.compositeServiceLevel, '-o', 'Color', colors(i,:), 'MarkerSize',4);
end
yline(0.90,'--','90% survivability threshold'); grid on; box on; ylim([0 1.05]); xlim([1 T]);
xlabel('Time (h)'); ylabel('Composite service level (p.u.)');
title('Resilience Recovery Curves under Section 5 Case Studies');
legend(strrep(names,'_','\_'), 'Location','southoutside','Orientation','horizontal');
exportgraphics(fig, fullfile(opts.resultDir,'Fig_Section5_resilience_curves.png'), 'Resolution', 600);

fig = figure('Name','Section 5 ENS','Color','w','Position',[100 100 950 520]); hold on;
ensMat = zeros(numel(names), T);
for i = 1:numel(names)
    m = unpack_metric(metricSet, names{i}); ensMat(i,:) = m.ENS_t;
end
bar(t, ensMat', 'stacked', 'EdgeColor','none'); grid on; box on;
xlabel('Time (h)'); ylabel('Electric ENS (MWh)'); title('Energy Not Served under Extreme Event Chains');
legend(strrep(names,'_','\_'), 'Location','northoutside','Orientation','horizontal');
exportgraphics(fig, fullfile(opts.resultDir,'Fig_Section5_ENS.png'), 'Resolution', 600);

% Use the first non-baseline case for detailed restoration/SOC figures.
detailIdx = find(~contains(names,'baseline','IgnoreCase',true),1,'first');
if isempty(detailIdx), detailIdx = 1; end
detailName = names{detailIdx};
r = resultSet.(detailName); m = unpack_metric(metricSet, detailName); sc = scenarioSet.(detailName);

fig = figure('Name','Restoration Trajectory','Color','w','Position',[120 120 980 620]);
subplot(2,1,1); hold on;
plot(t, 1 - sum(r.Pshed,1)./max(sum(caseData.Pd,1),1e-9), '-o', 'Color','#0072BD');
plot(t, m.criticalServiceLevel, '-s', 'Color','#D95319');
grid on; box on; ylim([0 1.05]); xlim([1 T]);
ylabel('Restored load ratio'); title('(a) Total and Critical Load Restoration');
legend('Total restored load','Critical load service','Location','best');
subplot(2,1,2); hold on;
stairs(t, sum(r.repaired(sc.faultedLines,:),1), '-o', 'Color','#77AC30');
stairs(t, sum(r.ysw,1), '-s', 'Color','#7E2F8E');
grid on; box on; xlim([1 T]); xlabel('Time (h)'); ylabel('Count');
title('(b) Repaired Fault Lines and Closed Switches');
legend('Repaired faulted lines','Closed lines/switches','Location','best');
exportgraphics(fig, fullfile(opts.resultDir,'Fig_Section5_restoration_trajectory.png'), 'Resolution', 600);

fig = figure('Name','SOC and Hydrogen Evolution','Color','w','Position',[140 140 980 620]);
subplot(2,1,1); hold on;
plot(t, r.Eb/caseData.bess.Emax, '-o', 'Color','#0072BD');
plot(t, r.Hsto/max(caseData.h2.Hmax,1e-9), '-s', 'Color','#7E2F8E');
grid on; box on; ylim([0 1.05]); xlim([1 T]); ylabel('SOC / SOHC');
title('(a) Battery SOC and Hydrogen Tank SOHC'); legend('Battery','Hydrogen tank','Location','best');
subplot(2,1,2); hold on;
bar(t, [r.Pfc(:), r.Pel(:), r.Hdis(:)], 'stacked', 'EdgeColor','none');
grid on; box on; xlim([1 T]); xlabel('Time (h)'); ylabel('MW / MWh-H_2 h^{-1}');
title('(b) Hydrogen-Assisted Recovery: Fuel Cell, Electrolyzer and Direct H_2 Supply');
legend('Fuel cell output','Electrolyzer charging','H_2 load supply','Location','best');
exportgraphics(fig, fullfile(opts.resultDir,'Fig_Section5_SOC_H2_evolution.png'), 'Resolution', 600);
end

function m = unpack_metric(metricSet, name)
if isfield(metricSet, name)
    m = metricSet.(name);
elseif isfield(metricSet,'metricsByCase') && isfield(metricSet.metricsByCase,name)
    m = metricSet.metricsByCase.(name);
else
    error('Metric field %s not found.', name);
end
end
