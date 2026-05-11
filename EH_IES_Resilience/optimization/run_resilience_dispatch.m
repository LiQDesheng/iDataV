function [dispatch, metrics, eventChain] = run_resilience_dispatch(caseData, scenarioType, opts)
%RUN_RESILIENCE_DISPATCH Section 5.3/5.4 resilience dispatch under extreme events.
%
% Inputs:
%   caseData     - IEEE 33-bus EH-IES data.
%   scenarioType - 'storm', 'wildfire', or 'ice_disaster'.
%   opts         - solver/event options.
% Outputs:
%   dispatch   - optimized resilience-oriented dispatch.
%   metrics    - resilience metrics.
%   eventChain - probabilistic cascading event-chain data.
%
% Equations mapping:
%   The generated event chain supplies a_l(t), rho_PV(t), rho_WT(t), and grid
%   availability to the MILP. The dispatch optimizes survival and restoration by
%   co-scheduling battery absorption, electrolyzer charging, hydrogen tank use,
%   fuel-cell black-start support, line switching, repair actions, and shedding.

if nargin < 2 || isempty(scenarioType), scenarioType = 'storm'; end
if nargin < 3, opts = struct(); end
eventOpts = struct('seed', get_opt(opts,'seed',2026), 'makePlots', get_opt(opts,'makeEventPlots',false), 'resultDir', get_opt(opts,'resultDir',''));
eventChain = generate_event_chain(caseData, scenarioType, eventOpts);
runOpts = opts;
runOpts.enableHydrogen = get_opt(opts,'enableHydrogen',true);
runOpts.enableMultiStageRestoration = get_opt(opts,'enableMultiStageRestoration',true);
runOpts.enableNetworkReconfiguration = get_opt(opts,'enableNetworkReconfiguration',true);
[dispatch, ~] = solve_resilience_milp(caseData, eventChain, runOpts);
metrics = compute_resilience_metrics(dispatch, caseData, eventChain);
end

function v = get_opt(opts, name, defaultValue)
if isfield(opts,name), v = opts.(name); else, v = defaultValue; end
end
