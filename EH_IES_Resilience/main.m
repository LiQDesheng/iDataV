%% Resilience-Oriented Multi-Stage Scheduling for EH-IES
% SCI-grade MATLAB/YALMIP entry point for Section 5 case studies.
%
% Paper: Resilience-Oriented Multi-Stage Scheduling for Electricity–Hydrogen
% Integrated Energy Systems: Multi-Timescale Absorption–Enhancement–Recovery
% Mechanisms Enabled by Hydrogen Storage.
%
% Requirements: MATLAB, YALMIP, and Gurobi or CPLEX.

clear; clc; close all;
yalmip('clear');

rootDir = fileparts(mfilename('fullpath'));
addpath(rootDir, fullfile(rootDir,'data'), fullfile(rootDir,'functions'), ...
    fullfile(rootDir,'optimization'), fullfile(rootDir,'plotting'), ...
    fullfile(rootDir,'scenarios'), fullfile(rootDir,'analysis'));

fprintf('\n=== EH-IES Section 5 Resilience Case-Study Platform ===\n');

opts = struct();
opts.solver = 'gurobi';          % change to 'cplex' if needed
opts.verbose = 1;
opts.seed = 2026;
opts.resultDir = fullfile(rootDir, 'results', 'Section5');
opts.enableHydrogen = true;
opts.enableMultiStageRestoration = true;
opts.enableNetworkReconfiguration = true;
opts.mipGap = 1e-4;
opts.timeLimit = 1800;
opts.makeEventPlots = true;

section5 = run_section5_case_studies(opts);
% Optional Section 6 mechanism analysis:
% section6 = run_section6_mechanism_analysis(setfield(opts, 'resultDir', fullfile(rootDir, 'results', 'Section6'))); %#ok<SFLD>

fprintf('\n=== Section 5 case studies completed. Results saved in: %s ===\n', opts.resultDir);
