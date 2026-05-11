function reshaping = analyze_restoration_reshaping(caseData, scenario, opts)
%ANALYZE_RESTORATION_RESHAPING Analyze how H2 reshapes restoration paths.
%
% Comparison:
%   A) restoration without hydrogen: no P2H/H2P/H2 tank support.
%   B) restoration with hydrogen: H2 tank and fuel cell provide black-start and
%      island survivability, allowing repair/switching sequences to prioritize
%      critical islands differently.
%
% Outputs quantify restoration sequence changes, island survivability changes,
% black-start support, restored load ratio, recovery-time reduction, and topology
% restoration paths for graph/animation visualization.

if nargin < 3, opts = struct(); end
noH2 = opts; noH2.enableHydrogen = false; noH2.enableP2H = false; noH2.enableH2P = false;
withH2 = opts; withH2.enableHydrogen = true; withH2.enableP2H = true; withH2.enableH2P = true;
[resNo, metNo, planNo] = run_restoration(caseData, scenario, noH2);
[resH2, metH2, planH2] = run_restoration(caseData, scenario, withH2);

reshaping = struct();
reshaping.withoutHydrogen.result = resNo;
reshaping.withoutHydrogen.metrics = metNo;
reshaping.withoutHydrogen.plan = planNo;
reshaping.withHydrogen.result = resH2;
reshaping.withHydrogen.metrics = metH2;
reshaping.withHydrogen.plan = planH2;
reshaping.restorationAcceleration_h = metNo.recoveryTime - metH2.recoveryTime;
reshaping.survivabilityGain_h = metH2.survivabilityHours - metNo.survivabilityHours;
reshaping.blackStartEnergy_MWh = sum(resH2.Pfc) * caseData.dt;
reshaping.sequenceDifference = sum(abs(resH2.repairAction(:) - resNo.repairAction(:))) + sum(abs(resH2.switchAction(:)-resNo.switchAction(:)));
reshaping.restoredLoadGain = planH2.restoredLoadRatio - planNo.restoredLoadRatio;
reshaping.loadRestorationHeatmap.withoutHydrogen = 1 - resNo.Pshed ./ max(caseData.Pd,1e-9);
reshaping.loadRestorationHeatmap.withHydrogen = 1 - resH2.Pshed ./ max(caseData.Pd,1e-9);

if isfield(opts,'resultDir') && ~isempty(opts.resultDir)
    plot_restoration_reshaping(reshaping, caseData, scenario, opts.resultDir);
end
end
