function plot_restoration_reshaping(reshaping, caseData, scenario, resultDir)
%PLOT_RESTORATION_RESHAPING Figures for hydrogen-driven restoration path reshaping.
if ~exist(resultDir,'dir'), mkdir(resultDir); end
set(groot,'defaultAxesFontName','Times New Roman','defaultTextFontName','Times New Roman','defaultAxesFontSize',11,'defaultLineLineWidth',2.0);
t = 1:caseData.T;
fig = figure('Name','Restoration Sequence Graph','Color','w','Position',[80 80 980 560]);
subplot(2,1,1); imagesc(reshaping.withoutHydrogen.result.repairAction); colorbar; ylabel('Line'); title('(a) Repair sequence without hydrogen');
subplot(2,1,2); imagesc(reshaping.withHydrogen.result.repairAction); colorbar; ylabel('Line'); xlabel('Time (h)'); title('(b) Repair sequence with hydrogen');
exportgraphics(fig, fullfile(resultDir,'Fig6_restoration_sequence_graph.png'), 'Resolution',600);
fig = figure('Name','Load Restoration Heatmap','Color','w','Position',[100 100 980 560]);
subplot(1,2,1); imagesc(reshaping.loadRestorationHeatmap.withoutHydrogen); colorbar; caxis([0 1]); title('Without H_2'); xlabel('Time (h)'); ylabel('Bus');
subplot(1,2,2); imagesc(reshaping.loadRestorationHeatmap.withHydrogen); colorbar; caxis([0 1]); title('With H_2'); xlabel('Time (h)'); ylabel('Bus');
exportgraphics(fig, fullfile(resultDir,'Fig6_load_restoration_heatmap.png'), 'Resolution',600);
fig = figure('Name','Hydrogen Dispatch Trajectory','Color','w','Position',[120 120 900 520]); r = reshaping.withHydrogen.result;
plot(t,r.Pfc,'-o'); hold on; plot(t,r.Pel,'-s'); plot(t,r.Hsto/max(caseData.h2.Hmax,1e-9),'--^'); grid on; box on;
xlabel('Time (h)'); ylabel('MW / SOHC'); title('Hydrogen Dispatch Trajectory for Restoration Reshaping'); legend('Fuel cell black-start','Electrolyzer P2H','Hydrogen SOHC','Location','best');
exportgraphics(fig, fullfile(resultDir,'Fig6_hydrogen_dispatch_trajectory.png'), 'Resolution',600);
create_topology_animation(resultWithDefaults(r,caseData), caseData, scenario, fullfile(resultDir,'Fig6_topology_restoration_animation.gif'));
end
function r = resultWithDefaults(r, caseData)
if ~isfield(r,'ysw'), r.ysw = zeros(caseData.Nl,caseData.T); end
if ~isfield(r,'zbus'), r.zbus = zeros(caseData.Nb,caseData.T); end
end
function create_topology_animation(result, caseData, scenario, gifFile)
xy = caseData.busXY;
for tt = 1:caseData.T
    fig = figure('Visible','off','Color','w','Position',[100 100 700 420]); hold on;
    for l = 1:caseData.Nl
        b1 = caseData.branch(l,1); b2 = caseData.branch(l,2);
        if result.ysw(l,tt) > 0.5, col = [0 0.45 0.74]; lw = 2.0; else, col = [0.75 0.75 0.75]; lw = 0.8; end
        plot(xy([b1 b2],1), xy([b1 b2],2), '-', 'Color', col, 'LineWidth', lw);
    end
    scatter(xy(:,1),xy(:,2),45, result.zbus(:,tt), 'filled'); caxis([0 1]); colormap([0.85 0.85 0.85; 0.2 0.6 0.2]);
    title(sprintf('Topology restoration at t = %d h (%s)', tt, scenario.stage(tt))); axis equal off;
    frame = getframe(fig); [A,map] = rgb2ind(frame2im(frame),256); close(fig);
    if tt == 1, imwrite(A,map,gifFile,'gif','LoopCount',Inf,'DelayTime',0.25); else, imwrite(A,map,gifFile,'gif','WriteMode','append','DelayTime',0.25); end
end
end
