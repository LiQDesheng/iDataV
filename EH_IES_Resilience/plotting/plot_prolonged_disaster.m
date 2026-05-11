function plot_prolonged_disaster(prolonged, resultDir)
%PLOT_PROLONGED_DISASTER Disaster-duration phase-transition plots.
if ~exist(resultDir,'dir'), mkdir(resultDir); end
tbl = prolonged.summaryTable; set(groot,'defaultAxesFontName','Times New Roman','defaultTextFontName','Times New Roman','defaultAxesFontSize',11,'defaultLineLineWidth',2.0);
fig = figure('Name','Prolonged Disaster Phase Transition','Color','w','Position',[80 80 1100 620]);
subplot(2,2,1); plot_by_mode(tbl,'ENS_MWh','ENS (MWh)'); title('(a) Duration vs ENS');
subplot(2,2,2); plot_by_mode(tbl,'ResilienceIndex','Resilience index'); title('(b) Duration vs resilience index');
subplot(2,2,3); plot_by_mode(tbl,'Survivability_h','Survivability (h)'); title('(c) Survivability window');
subplot(2,2,4); plot_by_mode(tbl,'HydrogenDominanceHours','H_2 dominance hours'); title('(d) Resilience phase transition');
exportgraphics(fig, fullfile(resultDir,'Fig6_prolonged_disaster_phase_transition.png'), 'Resolution',600);
end
function plot_by_mode(tbl, fieldName, ylab)
hold on; modes = unique(tbl.Mode);
for i = 1:numel(modes), idx = tbl.Mode == modes(i); plot(tbl.Duration_h(idx), tbl.(fieldName)(idx), '-o'); end
grid on; box on; xlabel('Disaster duration (h)'); ylabel(ylab); legend(modes,'Location','best');
end
