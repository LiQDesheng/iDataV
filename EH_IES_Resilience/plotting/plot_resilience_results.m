function plot_resilience_results(result, metrics, caseData, scenario, opts)
%PLOT_RESILIENCE_RESULTS Generate SCI-paper-quality resilience figures.
%
% Inputs:
%   result, metrics, caseData, scenario, opts - platform data structures.
% Outputs:
%   PNG and FIG files under opts.resultDir.
%
% Figure meanings:
%   Fig. 1 resilience/service curves; Fig. 2 storage absorption and hydrogen
%   recovery trajectories; Fig. 3 restoration status; Fig. 4 ENS decomposition.

if ~exist(opts.resultDir, 'dir'), mkdir(opts.resultDir); end
set(groot, 'defaultAxesFontName', 'Times New Roman', 'defaultTextFontName', 'Times New Roman');
set(groot, 'defaultAxesFontSize', 11, 'defaultLineLineWidth', 2.0);
T = caseData.T; t = 1:T;

stageColor = @(ax) add_stage_background(ax, scenario);

%% Figure 1: Resilience curves
fig = figure('Name','Resilience Curves','Color','w','Position',[80 80 900 520]); hold on;
plot(t, metrics.serviceLevel, '-o', 'Color','#0072BD', 'MarkerSize',4);
plot(t, metrics.criticalServiceLevel, '-s', 'Color','#D95319', 'MarkerSize',4);
plot(t, metrics.h2ServiceLevel, '-^', 'Color','#77AC30', 'MarkerSize',4);
plot(t, metrics.compositeServiceLevel, '-k', 'LineWidth',2.8);
yline(0.90,'--','90% survivability threshold','Color',[0.35 0.35 0.35]);
stageColor(gca); ylim([0 1.05]); xlim([1 T]); grid on; box on;
xlabel('Time (h)'); ylabel('Service level (p.u.)');
title('Multi-Stage Resilience Curves under Event-Chain Disturbance');
legend('All electric loads','Critical electric loads','Hydrogen demand','Composite resilience','Location','southoutside','Orientation','horizontal');
export_figure(fig, opts.resultDir, 'Fig1_resilience_curves');

%% Figure 2: Absorption-enhancement-recovery resources
fig = figure('Name','Hydrogen and Battery Mechanisms','Color','w','Position',[100 100 980 620]);
subplot(2,1,1); hold on;
plot(t, result.Eb/caseData.bess.Emax, '-o', 'Color','#0072BD', 'MarkerSize',4);
plot(t, result.Hsto/caseData.h2.Hmax, '-s', 'Color','#7E2F8E', 'MarkerSize',4);
stageColor(gca); ylim([0 1.05]); xlim([1 T]); grid on; box on;
ylabel('SOC / SOHC (p.u.)'); title('(a) Short-Term Battery Absorption vs. Long-Duration Hydrogen Reserve');
legend('Battery SOC','Hydrogen SOHC','Location','best');
subplot(2,1,2); hold on;
bar(t, [result.PbDis(:), result.Pfc(:), result.Pel(:)], 'stacked', 'EdgeColor','none');
stageColor(gca); xlim([1 T]); grid on; box on;
xlabel('Time (h)'); ylabel('Power (MW)'); title('(b) Battery Discharge, Fuel-Cell Support, and Electrolyzer Recovery Charging');
legend('Battery discharge','Fuel cell electric output','Electrolyzer consumption','Location','best');
export_figure(fig, opts.resultDir, 'Fig2_hydrogen_battery_mechanisms');

%% Figure 3: Restoration trajectory and topology recovery
fig = figure('Name','Restoration Trajectory','Color','w','Position',[120 120 950 560]);
subplot(2,1,1); hold on;
plot(t, sum(result.zbus,1), '-o', 'Color','#0072BD');
plot(t, sum(result.ysw,1), '-s', 'Color','#D95319');
stageColor(gca); xlim([1 T]); grid on; box on;
ylabel('Count'); title('(a) Energized Buses and Closed Branches');
legend('Energized buses','Closed branches','Location','best');
subplot(2,1,2); hold on;
stairs(t, sum(result.repaired(scenario.faultedLines,:),1), 'Color','#77AC30', 'LineWidth',2.4);
bar(t, sum(result.repairAction(scenario.faultedLines,:),1), 0.45, 'FaceColor','#EDB120', 'EdgeColor','none');
stageColor(gca); xlim([1 T]); grid on; box on;
xlabel('Time (h)'); ylabel('Faulted-line count'); title('(b) Multi-Stage Repair Sequencing');
legend('Cumulative repaired lines','Hourly repair actions','Location','best');
export_figure(fig, opts.resultDir, 'Fig3_restoration_trajectory');

%% Figure 4: ENS and hydrogen ENS decomposition
fig = figure('Name','ENS Analysis','Color','w','Position',[140 140 950 520]); hold on;
yyaxis left;
bar(t, [metrics.ENS_t(:), metrics.criticalENS_t(:)], 'grouped', 'EdgeColor','none');
ylabel('Electric ENS (MWh)');
yyaxis right;
plot(t, metrics.HENS_t, '-^', 'Color','#7E2F8E', 'MarkerFaceColor','#DAB6EA');
ylabel('Hydrogen ENS (MWh-H_2)');
stageColor(gca); xlim([1 T]); grid on; box on;
xlabel('Time (h)'); title('Electric and Hydrogen Energy-Not-Served Analysis');
legend('Total electric ENS','Critical-load ENS','Hydrogen ENS','Location','northoutside','Orientation','horizontal');
export_figure(fig, opts.resultDir, 'Fig4_ENS_analysis');
end

function add_stage_background(ax, scenario)
yl = ylim(ax); hold(ax,'on');
patch(ax,[5.5 15.5 15.5 5.5],[yl(1) yl(1) yl(2) yl(2)],[1.0 0.88 0.88], 'EdgeColor','none','FaceAlpha',0.25,'HandleVisibility','off');
patch(ax,[15.5 24.5 24.5 15.5],[yl(1) yl(1) yl(2) yl(2)],[0.88 0.94 1.0], 'EdgeColor','none','FaceAlpha',0.20,'HandleVisibility','off');
text(ax,3,yl(2)-0.05*(yl(2)-yl(1)),'Pre-event','FontWeight','bold','HorizontalAlignment','center');
text(ax,10.5,yl(2)-0.05*(yl(2)-yl(1)),'Islanded event','FontWeight','bold','HorizontalAlignment','center');
text(ax,20,yl(2)-0.05*(yl(2)-yl(1)),'Restoration','FontWeight','bold','HorizontalAlignment','center');
uistack(findobj(ax,'Type','patch'),'bottom');
end

function export_figure(fig, resultDir, name)
exportgraphics(fig, fullfile(resultDir, [name '.png']), 'Resolution', 600);
savefig(fig, fullfile(resultDir, [name '.fig']));
end
