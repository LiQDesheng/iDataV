function plot_section6_mechanisms(section6, opts)
%PLOT_SECTION6_MECHANISMS Generate integrated Section 6 mechanism figures.
%
% Inputs:
%   section6 - output of run_section6_mechanism_analysis.
%   opts     - contains resultDir.
% Output:
%   High-resolution figures for multi-timescale mechanisms, resilience-economy
%   tradeoff, functional division, event severity evolution and prolonged disasters.

if nargin < 2, opts = struct(); end
if ~isfield(opts,'resultDir') || isempty(opts.resultDir), opts.resultDir = fullfile(pwd,'results','Section6'); end
if ~exist(opts.resultDir,'dir'), mkdir(opts.resultDir); end
set(groot,'defaultAxesFontName','Times New Roman','defaultTextFontName','Times New Roman','defaultAxesFontSize',11,'defaultLineLineWidth',2.0);

if isfield(section6,'durationMechanisms')
    tbl = section6.durationMechanisms;
    fig = figure('Name','Multi-timescale Resilience Mechanism','Color','w','Position',[80 80 980 580]);
    subplot(2,2,1); plot(tbl.Duration_h,tbl.Survivability_h,'-o'); grid on; box on; xlabel('Disaster duration (h)'); ylabel('Survivability window (h)'); title('(a) Survivability enhancement');
    subplot(2,2,2); plot(tbl.Duration_h,tbl.ResilienceIndex,'-s'); grid on; box on; xlabel('Disaster duration (h)'); ylabel('Resilience index'); title('(b) Resilience degradation');
    subplot(2,2,3); plot(tbl.Duration_h,tbl.BatteryContribution_MWh,'-o'); hold on; plot(tbl.Duration_h,tbl.HydrogenContribution_MWh,'-^'); grid on; box on; xlabel('Disaster duration (h)'); ylabel('Contribution (MWh)'); title('(c) Battery-Hydrogen functional transition'); legend('Battery','Hydrogen','Location','best');
    subplot(2,2,4); plot(tbl.Duration_h,tbl.RecoverySpeed_pu_per_h,'-d'); grid on; box on; xlabel('Disaster duration (h)'); ylabel('Recovery speed (p.u./h)'); title('(d) Restoration acceleration');
    exportgraphics(fig, fullfile(opts.resultDir,'Fig6_multi_timescale_mechanism.png'), 'Resolution',600);
end

if isfield(section6,'economyTradeoff')
    tbl = section6.economyTradeoff;
    fig = figure('Name','Resilience-Economy Tradeoff','Color','w','Position',[100 100 760 520]);
    scatter(tbl.TotalCost_USD/1e3, tbl.ResilienceIndex, 90, tbl.HydrogenContribution_MWh, 'filled'); colorbar; grid on; box on;
    xlabel('Total cost (10^3 $)'); ylabel('Resilience index'); title('Resilience-Economy Tradeoff Colored by Hydrogen Contribution');
    exportgraphics(fig, fullfile(opts.resultDir,'Fig6_resilience_economy_tradeoff.png'), 'Resolution',600);
end
end

function plot_functional_division(division, caseData, scenario, resultDir)
%PLOT_FUNCTIONAL_DIVISION Figures for battery-only/H2-only/hybrid comparison.
if ~exist(resultDir,'dir'), mkdir(resultDir); end
names = fieldnames(division.results); t = 1:caseData.T; colors = lines(numel(names));
fig = figure('Name','Functional Division SOC','Color','w','Position',[80 80 980 620]);
subplot(2,1,1); hold on;
for i = 1:numel(names), r = division.results.(names{i}); plot(t,r.Eb/max(caseData.bess.Emax,1e-9),'Color',colors(i,:)); end
grid on; box on; ylabel('Battery SOC'); title('(a) SOC trajectories'); legend(strrep(names,'_','\_'),'Location','best');
subplot(2,1,2); hold on;
for i = 1:numel(names), r = division.results.(names{i}); plot(t,r.Hsto/max(caseData.h2.Hmax,1e-9),'Color',colors(i,:)); end
grid on; box on; xlabel('Time (h)'); ylabel('H_2 SOHC'); title('(b) Hydrogen storage trajectories');
exportgraphics(fig, fullfile(resultDir,'Fig6_functional_division_SOC.png'), 'Resolution',600);

fig = figure('Name','Functional Division Contributions','Color','w','Position',[100 100 980 560]);
hybrid = division.mechanisms.hybrid;
bar(t, [hybrid.batteryContribution(:), hybrid.hydrogenContribution(:)], 'stacked','EdgeColor','none'); grid on; box on;
xlabel('Time (h)'); ylabel('Dynamic resilience contribution (MWh)'); title('Temporal Resilience Shifting: Battery \rightarrow Hydrogen Dominance'); legend('Battery','Hydrogen','Location','best');
exportgraphics(fig, fullfile(resultDir,'Fig6_stacked_energy_contribution.png'), 'Resolution',600);

fig = figure('Name','Functional Division Resilience Curves','Color','w','Position',[120 120 900 520]); hold on;
for i = 1:numel(names), m = division.metrics.(names{i}); plot(t,m.compositeServiceLevel,'-o','Color',colors(i,:),'MarkerSize',4); end
grid on; box on; ylim([0 1.05]); xlabel('Time (h)'); ylabel('Resilience index (p.u.)'); title('Battery-only vs Hydrogen-only vs Hybrid Resilience Curves'); legend(strrep(names,'_','\_'),'Location','southoutside','Orientation','horizontal');
exportgraphics(fig, fullfile(resultDir,'Fig6_functional_division_resilience_curves.png'), 'Resolution',600);
end

function plot_restoration_reshaping(reshaping, caseData, scenario, resultDir)
%PLOT_RESTORATION_RESHAPING Topology/path and H2 dispatch figures.
if ~exist(resultDir,'dir'), mkdir(resultDir); end
t = 1:caseData.T;
fig = figure('Name','Restoration Sequence Graph','Color','w','Position',[80 80 980 560]);
subplot(2,1,1); imagesc(reshaping.withoutHydrogen.result.repairAction); colorbar; ylabel('Line'); title('(a) Repair sequence without hydrogen');
subplot(2,1,2); imagesc(reshaping.withHydrogen.result.repairAction); colorbar; ylabel('Line'); xlabel('Time (h)'); title('(b) Repair sequence with hydrogen');
exportgraphics(fig, fullfile(resultDir,'Fig6_restoration_sequence_graph.png'), 'Resolution',600);

fig = figure('Name','Load Restoration Heatmap','Color','w','Position',[100 100 980 560]);
subplot(1,2,1); imagesc(reshaping.loadRestorationHeatmap.withoutHydrogen); colorbar; caxis([0 1]); title('Without H_2'); xlabel('Time (h)'); ylabel('Bus');
subplot(1,2,2); imagesc(reshaping.loadRestorationHeatmap.withHydrogen); colorbar; caxis([0 1]); title('With H_2'); xlabel('Time (h)'); ylabel('Bus');
exportgraphics(fig, fullfile(resultDir,'Fig6_load_restoration_heatmap.png'), 'Resolution',600);

fig = figure('Name','Hydrogen Dispatch Trajectory','Color','w','Position',[120 120 900 520]);
r = reshaping.withHydrogen.result;
plot(t,r.Pfc,'-o'); hold on; plot(t,r.Pel,'-s'); plot(t,r.Hsto/max(caseData.h2.Hmax,1e-9),'--^'); grid on; box on;
xlabel('Time (h)'); ylabel('MW / SOHC'); title('Hydrogen Dispatch Trajectory for Restoration Reshaping'); legend('Fuel cell black-start','Electrolyzer P2H','Hydrogen SOHC','Location','best');
exportgraphics(fig, fullfile(resultDir,'Fig6_hydrogen_dispatch_trajectory.png'), 'Resolution',600);

create_topology_animation(reshaping.withHydrogen.result, caseData, scenario, fullfile(resultDir,'Fig6_topology_restoration_animation.gif'));
end

function plot_ablation_results(ablation, resultDir)
if ~exist(resultDir,'dir'), mkdir(resultDir); end
tbl = ablation.summaryTable;
fig = figure('Name','Mechanism Ablation Bars','Color','w','Position',[80 80 1100 600]);
subplot(2,1,1); bar(categorical(tbl.Case), tbl.ENS_MWh); ylabel('ENS (MWh)'); title('(a) ENS degradation'); grid on; box on; xtickangle(25);
subplot(2,1,2); bar(categorical(tbl.Case), tbl.ResilienceIndex); ylabel('Resilience index'); title('(b) Resilience loss'); grid on; box on; xtickangle(25);
exportgraphics(fig, fullfile(resultDir,'Fig6_ablation_bar_charts.png'), 'Resolution',600);

names = fieldnames(ablation.metrics); fig = figure('Name','Ablation Resilience Curves','Color','w','Position',[100 100 980 520]); hold on; colors = lines(numel(names));
for i = 1:numel(names), plot(ablation.metrics.(names{i}).time, ablation.metrics.(names{i}).compositeServiceLevel,'Color',colors(i,:)); end
grid on; box on; ylim([0 1.05]); xlabel('Time (h)'); ylabel('Composite service level'); title('Ablation Resilience Curves'); legend(strrep(names,'_','\_'),'Location','eastoutside');
exportgraphics(fig, fullfile(resultDir,'Fig6_ablation_resilience_curves.png'), 'Resolution',600);
end

function plot_prolonged_disaster(prolonged, resultDir)
if ~exist(resultDir,'dir'), mkdir(resultDir); end
tbl = prolonged.summaryTable;
fig = figure('Name','Prolonged Disaster Phase Transition','Color','w','Position',[80 80 1100 620]);
subplot(2,2,1); plot_by_mode(tbl,'ENS_MWh','ENS (MWh)'); title('(a) Duration vs ENS');
subplot(2,2,2); plot_by_mode(tbl,'ResilienceIndex','Resilience index'); title('(b) Duration vs resilience index');
subplot(2,2,3); plot_by_mode(tbl,'Survivability_h','Survivability (h)'); title('(c) Survivability window');
subplot(2,2,4); plot_by_mode(tbl,'HydrogenDominanceHours','H_2 dominance hours'); title('(d) Resilience phase transition');
exportgraphics(fig, fullfile(resultDir,'Fig6_prolonged_disaster_phase_transition.png'), 'Resolution',600);
end

function plot_by_mode(tbl, fieldName, ylab)
hold on; modes = unique(tbl.Mode);
for i = 1:numel(modes)
    idx = tbl.Mode == modes(i); plot(tbl.Duration_h(idx), tbl.(fieldName)(idx), '-o');
end
grid on; box on; xlabel('Disaster duration (h)'); ylabel(ylab); legend(modes,'Location','best');
end

function create_topology_animation(result, caseData, scenario, gifFile)
%CREATE_TOPOLOGY_ANIMATION Animated restoration topology for journal supplement.
xy = caseData.busXY;
for t = 1:caseData.T
    fig = figure('Visible','off','Color','w','Position',[100 100 700 420]); hold on;
    for l = 1:caseData.Nl
        b1 = caseData.branch(l,1); b2 = caseData.branch(l,2);
        if result.ysw(l,t) > 0.5, col = [0 0.45 0.74]; lw = 2.0; else, col = [0.75 0.75 0.75]; lw = 0.8; end
        plot(xy([b1 b2],1), xy([b1 b2],2), '-', 'Color', col, 'LineWidth', lw);
    end
    scatter(xy(:,1),xy(:,2),45, result.zbus(:,t), 'filled'); caxis([0 1]); colormap([0.85 0.85 0.85; 0.2 0.6 0.2]);
    title(sprintf('Topology restoration at t = %d h (%s)', t, scenario.stage(t))); axis equal off;
    frame = getframe(fig); [A,map] = rgb2ind(frame2im(frame),256); close(fig);
    if t == 1, imwrite(A,map,gifFile,'gif','LoopCount',Inf,'DelayTime',0.25); else, imwrite(A,map,gifFile,'gif','WriteMode','append','DelayTime',0.25); end
end
end
