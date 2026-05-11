function section5 = run_section5_case_studies(opts)
%RUN_SECTION5_CASE_STUDIES Complete Section 5 case-study workflow.
%
% Paper section mapping:
%   5.1 Test system and event-chain configuration
%   5.2 Baseline normal operation
%   5.3 Resilience-oriented dispatch under extreme events
%   5.4 Extreme event-chain scenarios: storm/wildfire/ice disaster
%   5.5 Hydrogen-assisted multi-stage restoration
%   5.6 Impact of disaster duration
%   5.7 Battery-only vs hydrogen-enabled comparison
%   5.8 Comprehensive resilience assessment
%
% Usage:
%   section5 = run_section5_case_studies(struct('solver','gurobi'));

if nargin < 1, opts = struct(); end
rootDir = fileparts(mfilename('fullpath'));
addpath(rootDir, fullfile(rootDir,'data'), fullfile(rootDir,'functions'), ...
    fullfile(rootDir,'optimization'), fullfile(rootDir,'plotting'), fullfile(rootDir,'scenarios'));
opts = fill_section5_defaults(opts, rootDir);
if ~exist(opts.resultDir,'dir'), mkdir(opts.resultDir); end

%% 5.1 Test system and event-chain configuration
caseData = build_case33_ehies();
storm = generate_event_chain(caseData, 'storm', struct('seed',opts.seed,'makePlots',true,'resultDir',opts.resultDir));

%% 5.2 Baseline normal operation
[baseline, baselineMetrics, baselineScenario] = run_baseline_operation(caseData, opts);

%% 5.3 Resilience-oriented dispatch under extreme events
[stormDispatch, stormMetrics, stormScenario] = run_resilience_dispatch(caseData, 'storm', opts);

%% 5.4 Extreme event-chain scenarios
scenarioNames = {'storm','wildfire','ice_disaster'};
extremeResults = struct(); extremeMetrics = struct(); extremeScenarios = struct();
for i = 1:numel(scenarioNames)
    [extremeResults.(scenarioNames{i}), extremeMetrics.(scenarioNames{i}), extremeScenarios.(scenarioNames{i})] = ...
        run_resilience_dispatch(caseData, scenarioNames{i}, opts);
end

%% 5.5 Hydrogen-assisted multi-stage restoration
[restoration, restorationMetrics, restorationPlan] = run_restoration(caseData, stormScenario, opts);

%% 5.6 Impact of disaster duration
[durationTable, durationCases] = run_duration_sensitivity(caseData, stormScenario, opts, [6 10 14 18]);

%% 5.7 Battery-only vs hydrogen-enabled comparison
h2Opts = opts; h2Opts.enableHydrogen = true;
battOpts = opts; battOpts.enableHydrogen = false;
[h2Case, h2Metrics, h2Scenario] = run_resilience_dispatch(caseData, 'storm', h2Opts);
[batteryOnly, batteryMetrics, batteryScenario] = run_resilience_dispatch(caseData, 'storm', battOpts);
comparisonResults = struct('hydrogen_enabled', h2Case, 'battery_only', batteryOnly);
comparisonScenarios = struct('hydrogen_enabled', h2Scenario, 'battery_only', batteryScenario);
comparisonAssessment = evaluate_resilience_metrics(comparisonResults, caseData, comparisonScenarios);

%% 5.8 Comprehensive resilience assessment
resultSet = struct('baseline', baseline, 'storm_dispatch', stormDispatch, ...
    'storm_restoration', restoration, 'battery_only', batteryOnly, 'hydrogen_enabled', h2Case);
scenarioSet = struct('baseline', baselineScenario, 'storm_dispatch', stormScenario, ...
    'storm_restoration', stormScenario, 'battery_only', batteryScenario, 'hydrogen_enabled', h2Scenario);
assessment = evaluate_resilience_metrics(resultSet, caseData, scenarioSet);
metricSet = assessment.metricsByCase;
plot_resilience_curves(resultSet, metricSet, caseData, scenarioSet, opts);
writetable(assessment.summaryTable, fullfile(opts.resultDir, 'Section5_comprehensive_resilience_assessment.csv'));
writetable(durationTable, fullfile(opts.resultDir, 'Section5_disaster_duration_sensitivity.csv'));
writetable(comparisonAssessment.summaryTable, fullfile(opts.resultDir, 'Section5_battery_vs_hydrogen.csv'));

section5 = struct();
section5.caseData = caseData;
section5.referenceEventChain = storm;
section5.baseline = baseline;
section5.baselineMetrics = baselineMetrics;
section5.extremeResults = extremeResults;
section5.extremeMetrics = extremeMetrics;
section5.extremeScenarios = extremeScenarios;
section5.restoration = restoration;
section5.restorationMetrics = restorationMetrics;
section5.restorationPlan = restorationPlan;
section5.durationTable = durationTable;
section5.durationCases = durationCases;
section5.comparisonAssessment = comparisonAssessment;
section5.assessment = assessment;
save(fullfile(opts.resultDir, 'Section5_case_studies_workspace.mat'), 'section5');
end

function [durationTable, durationCases] = run_duration_sensitivity(caseData, baseScenario, opts, durations)
durationCases = struct(); records = cell(numel(durations),1);
for i = 1:numel(durations)
    sc = stretch_event_duration(baseScenario, durations(i), caseData);
    [res, met] = run_restoration(caseData, sc, opts);
    caseName = sprintf('duration_%dh', durations(i));
    durationCases.(caseName).scenario = sc;
    durationCases.(caseName).result = res;
    durationCases.(caseName).metrics = met;
    records{i} = met.summary;
    records{i}.DisasterDuration_h = durations(i);
end
durationTable = struct2table(vertcat(records{:}));
durationTable = movevars(durationTable, 'DisasterDuration_h', 'Before', 1);
end

function sc = stretch_event_duration(sc, duration, caseData)
T = caseData.T;
firstEvent = find(sc.stage == "during-event-islanded", 1, 'first');
if isempty(firstEvent), firstEvent = 6; end
endEvent = min(T, firstEvent + duration - 1);
sc.gridAvailable(:) = true; sc.gridAvailable(firstEvent:endEvent) = false;
sc.stage(:) = "post-event-restoration"; sc.stage(1:firstEvent-1) = "pre-event"; sc.stage(firstEvent:endEvent) = "during-event-islanded";
sc.isPre = sc.stage == "pre-event"; sc.isDuring = sc.stage == "during-event-islanded"; sc.isPost = sc.stage == "post-event-restoration";
sc.pvMultiplier(:) = 1; sc.wtMultiplier(:) = 1;
sc.pvMultiplier(firstEvent:endEvent) = min(sc.pvMultiplier(firstEvent:endEvent), 0.45);
sc.wtMultiplier(firstEvent:endEvent) = min(sc.wtMultiplier(firstEvent:endEvent), 0.55);
sc.renewableDerating.pv = sc.pvMultiplier; sc.renewableDerating.wt = sc.wtMultiplier;
sc.branchAvailableBase = true(caseData.Nl,T);
if ~isempty(sc.faultedLines)
    sc.branchAvailableBase(sc.faultedLines, firstEvent:T) = false;
    sc.lineStatus = sc.branchAvailableBase;
    sc.earliestRepairHour = containers.Map('KeyType','double','ValueType','double');
    sc.faultStartHour = containers.Map('KeyType','double','ValueType','double');
    for l = sc.faultedLines
        sc.faultStartHour(l) = firstEvent;
        sc.earliestRepairHour(l) = min(T, endEvent + 1);
    end
end
sc.name = sprintf('%s_duration_%dh', sc.name, duration);
end

function opts = fill_section5_defaults(opts, rootDir)
if ~isfield(opts,'solver'), opts.solver = 'gurobi'; end
if ~isfield(opts,'verbose'), opts.verbose = 1; end
if ~isfield(opts,'seed'), opts.seed = 2026; end
if ~isfield(opts,'resultDir'), opts.resultDir = fullfile(rootDir,'results','Section5'); end
if ~isfield(opts,'enableHydrogen'), opts.enableHydrogen = true; end
if ~isfield(opts,'enableMultiStageRestoration'), opts.enableMultiStageRestoration = true; end
if ~isfield(opts,'enableNetworkReconfiguration'), opts.enableNetworkReconfiguration = true; end
if ~isfield(opts,'mipGap'), opts.mipGap = 1e-4; end
if ~isfield(opts,'timeLimit'), opts.timeLimit = 1800; end
if ~isfield(opts,'makeEventPlots'), opts.makeEventPlots = true; end
end
