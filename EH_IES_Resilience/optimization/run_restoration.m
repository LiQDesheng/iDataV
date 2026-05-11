function [restoration, metrics, restorationPlan] = run_restoration(caseData, eventChain, opts)
%RUN_RESTORATION Multi-stage resilience restoration optimization for EH-IES.
%
% Section 5.5 module: hydrogen-assisted multi-stage restoration.
%
% Inputs:
%   caseData   - IEEE 33-bus EH-IES data.
%   eventChain - output of generate_event_chain.m.
%   opts       - solver options and mechanism switches.
% Outputs:
%   restoration     - optimized MILP schedules for restoration.
%   metrics         - recovery metrics and service curves.
%   restorationPlan - stage-wise repair, switching, restored-load and black-start data.
%
% Restoration stages:
%   Stage 1 emergency survival: critical load restoration during islanding.
%   Stage 2 partial feeder restoration: distributed island coordination, line switching.
%   Stage 3 full recovery: repaired lines are reconnected and terminal reserves rebuilt.
%
% MILP ingredients:
%   y_l,t line switching, x_l,t repair action, r_l,t repaired state, z_i,t energized
%   bus state, P_shed weighted by hospital/communication/emergency/industrial/
%   residential priority, battery SOC, hydrogen tank SOHC, electrolyzer/fuel cell
%   coupling and fuel-cell black-start capability.

if nargin < 3, opts = struct(); end
opts.enableHydrogen = get_opt(opts,'enableHydrogen',true);
opts.enableMultiStageRestoration = true;
opts.enableNetworkReconfiguration = get_opt(opts,'enableNetworkReconfiguration',true);
[restoration, ~] = solve_resilience_milp(caseData, eventChain, opts);
metrics = compute_resilience_metrics(restoration, caseData, eventChain);
restorationPlan = build_restoration_plan(restoration, metrics, caseData, eventChain);
end

function plan = build_restoration_plan(result, metrics, caseData, eventChain)
T = caseData.T;
plan = struct();
plan.stageName = strings(1,T);
for t = 1:T
    if eventChain.isDuring(t)
        plan.stageName(t) = "Stage 1: emergency survival";
    elseif eventChain.isPost(t) && metrics.compositeServiceLevel(t) < 0.98
        plan.stageName(t) = "Stage 2: partial feeder restoration";
    else
        plan.stageName(t) = "Stage 3: full system recovery";
    end
end
plan.restoredLoadRatio = 1 - sum(result.Pshed,1) ./ max(sum(caseData.Pd,1),1e-9);
plan.criticalRestoredRatio = 1 - metrics.criticalENS_t ./ max(sum(caseData.Pd(eventChain.criticalBuses,:),1),1e-9);
plan.repairedLineCount = sum(result.repaired(eventChain.faultedLines,:),1);
plan.repairActions = result.repairAction;
plan.switchingActions = result.switchAction;
plan.blackStartPower = result.Pfc;
plan.recoveryTime = metrics.recoveryTime;
plan.priorityRestoration = priority_restoration_table(result, caseData);
end

function tbl = priority_restoration_table(result, caseData)
classes = unique(string(caseData.loadClass));
served = zeros(numel(classes),1); demand = served;
for k = 1:numel(classes)
    idx = strcmp(string(caseData.loadClass), classes(k));
    demand(k) = sum(caseData.Pd(idx,:), 'all');
    served(k) = demand(k) - sum(result.Pshed(idx,:), 'all');
end
tbl = table(classes(:), demand, served, served./max(demand,1e-9), ...
    'VariableNames', {'LoadClass','DemandMWh','ServedMWh','RestoredRatio'});
end

function v = get_opt(opts, name, defaultValue)
if isfield(opts,name), v = opts.(name); else, v = defaultValue; end
end
