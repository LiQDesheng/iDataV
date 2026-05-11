function plot_functional_division(division, caseData, scenario, resultDir)
%PLOT_FUNCTIONAL_DIVISION Publication figures for BESS/H2 functional division.
if ~exist(resultDir,'dir'), mkdir(resultDir); end %#ok<*INUSD>
set(groot,'defaultAxesFontName','Times New Roman','defaultTextFontName','Times New Roman','defaultAxesFontSize',11,'defaultLineLineWidth',2.0);
names = fieldnames(division.results); t = 1:caseData.T; colors = lines(numel(names));
fig = figure('Name','Functional Division SOC','Color','w','Position',[80 80 980 620]);
subplot(2,1,1); hold on; for i = 1:numel(names), r = division.results.(names{i}); plot(t,r.Eb/max(caseData.bess.Emax,1e-9),'Color',colors(i,:)); end
grid on; box on; ylabel('Battery SOC'); title('(a) Battery absorption trajectory'); legend(strrep(names,'_','\_'),'Location','best');
subplot(2,1,2); hold on; for i = 1:numel(names), r = division.results.(names{i}); plot(t,r.Hsto/max(caseData.h2.Hmax,1e-9),'Color',colors(i,:)); end
grid on; box on; xlabel('Time (h)'); ylabel('H_2 SOHC'); title('(b) Hydrogen survivability trajectory');
exportgraphics(fig, fullfile(resultDir,'Fig6_functional_division_SOC.png'), 'Resolution',600);
fig = figure('Name','Temporal Resilience Shifting','Color','w','Position',[100 100 980 560]); hybrid = division.mechanisms.hybrid;
bar(t, [hybrid.batteryContribution(:), hybrid.hydrogenContribution(:)], 'stacked','EdgeColor','none'); grid on; box on;
xlabel('Time (h)'); ylabel('Contribution (MWh)'); title('Temporal Resilience Shifting: Battery \rightarrow Hydrogen'); legend('Battery','Hydrogen','Location','best');
exportgraphics(fig, fullfile(resultDir,'Fig6_temporal_resilience_shifting.png'), 'Resolution',600);
fig = figure('Name','Functional Division Resilience Curves','Color','w','Position',[120 120 900 520]); hold on;
for i = 1:numel(names), m = division.metrics.(names{i}); plot(t,m.compositeServiceLevel,'-o','Color',colors(i,:),'MarkerSize',4); end
grid on; box on; ylim([0 1.05]); xlabel('Time (h)'); ylabel('Resilience index (p.u.)'); title('Battery-only vs Hydrogen-only vs Hybrid'); legend(strrep(names,'_','\_'),'Location','southoutside','Orientation','horizontal');
exportgraphics(fig, fullfile(resultDir,'Fig6_functional_division_resilience_curves.png'), 'Resolution',600);
end
