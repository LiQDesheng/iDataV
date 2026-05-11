function plot_ablation_results(ablation, resultDir)
%PLOT_ABLATION_RESULTS SCI-quality ablation comparison figures.
if ~exist(resultDir,'dir'), mkdir(resultDir); end
tbl = ablation.summaryTable; set(groot,'defaultAxesFontName','Times New Roman','defaultTextFontName','Times New Roman','defaultAxesFontSize',10,'defaultLineLineWidth',1.8);
fig = figure('Name','Mechanism Ablation Bars','Color','w','Position',[80 80 1100 600]);
subplot(2,1,1); bar(categorical(tbl.Case), tbl.ENS_MWh); ylabel('ENS (MWh)'); title('(a) ENS degradation'); grid on; box on; xtickangle(25);
subplot(2,1,2); bar(categorical(tbl.Case), tbl.ResilienceIndex); ylabel('Resilience index'); title('(b) Resilience loss'); grid on; box on; xtickangle(25);
exportgraphics(fig, fullfile(resultDir,'Fig6_ablation_bar_charts.png'), 'Resolution',600);
names = fieldnames(ablation.metrics); fig = figure('Name','Ablation Resilience Curves','Color','w','Position',[100 100 980 520]); hold on; colors = lines(numel(names));
for i = 1:numel(names), plot(ablation.metrics.(names{i}).time, ablation.metrics.(names{i}).compositeServiceLevel,'Color',colors(i,:)); end
grid on; box on; ylim([0 1.05]); xlabel('Time (h)'); ylabel('Composite service level'); title('Ablation Resilience Curves'); legend(strrep(names,'_','\_'),'Location','eastoutside');
exportgraphics(fig, fullfile(resultDir,'Fig6_ablation_resilience_curves.png'), 'Resolution',600);
end
