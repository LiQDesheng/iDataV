function caseData = build_case33_ehies()
%BUILD_CASE33_EHIES Build a modified IEEE 33-bus EH-IES test system.
%
% Output:
%   caseData - struct containing network, multi-energy devices, load, RES,
%              economics, and resilience parameters.
%
% Mathematical meaning:
%   The distribution feeder is represented by a switchable radial graph. Electric
%   loads are located at IEEE 33 buses, while hydrogen conversion/storage devices
%   are placed at resilience-critical buses to support prolonged outage recovery.

caseData = struct();
caseData.baseMVA = 1.0;
caseData.Nb = 33;
caseData.T = 24;
caseData.dt = 1.0;
caseData.bus = (1:caseData.Nb)';
caseData.slackBus = 1;

% IEEE 33-bus normally closed branches plus five tie switches.
caseData.branch = [ ...
    1 2; 2 3; 3 4; 4 5; 5 6; 6 7; 7 8; 8 9; 9 10; 10 11; 11 12; 12 13; ...
    13 14; 14 15; 15 16; 16 17; 17 18; 2 19; 19 20; 20 21; 21 22; 3 23; ...
    23 24; 24 25; 6 26; 26 27; 27 28; 28 29; 29 30; 30 31; 31 32; 32 33; ...
    8 21; 9 15; 12 22; 18 33; 25 29];
caseData.Nl = size(caseData.branch,1);
caseData.normallyClosed = [true(32,1); false(5,1)];
caseData.lineCap = [2.5*ones(32,1); 1.5*ones(5,1)];      % MW
caseData.switchable = true(caseData.Nl,1);

% Baseline IEEE 33 load shape (MW) distributed over buses; bus 1 has no load.
pd = zeros(caseData.Nb,1);
pd([2:33]) = [0.10 0.09 0.12 0.06 0.06 0.20 0.20 0.06 0.06 0.045 0.06 0.06 ...
    0.12 0.06 0.06 0.06 0.09 0.09 0.09 0.09 0.09 0.09 0.42 0.42 0.06 0.06 ...
    0.06 0.12 0.20 0.15 0.21 0.06];
loadShape = [0.62 0.58 0.55 0.54 0.57 0.70 0.86 1.02 1.10 1.06 1.00 0.96 ...
    0.94 0.98 1.05 1.12 1.25 1.36 1.42 1.33 1.16 0.98 0.82 0.70];
caseData.Pd = pd * loadShape;

% Criticality weights: hospital/data-center/hydrogen mobility loads are costly.
caseData.loadPriority = ones(caseData.Nb,1);
caseData.loadPriority([6 18 25 30 33]) = [4 5 3 4 5];
caseData.loadClass = repmat({'residential'}, caseData.Nb, 1);
caseData.loadClass([6 18 25 30 33]) = {'hospital', 'communication', 'emergency', 'industrial', 'hydrogen-hub'};
caseData.priorityName = {'residential', 'industrial', 'emergency services', 'hospital', 'communication/hydrogen hub'};
caseData.blackStartBuses = [caseData.slackBus, 18, 30];

% Renewable profiles and siting.
caseData.pvBus = [10 24 30];
caseData.pvCap = [0.80 0.60 0.50]';
caseData.wtBus = [14 32];
caseData.wtCap = [0.70 0.90]';
caseData.pvProfile = [0 0 0 0 0 0.02 0.12 0.28 0.48 0.68 0.82 0.91 0.88 0.78 0.61 0.40 0.18 0.05 0 0 0 0 0 0];
caseData.wtProfile = [0.62 0.65 0.68 0.70 0.66 0.61 0.55 0.48 0.42 0.38 0.35 0.34 ...
    0.36 0.40 0.46 0.52 0.60 0.70 0.74 0.72 0.69 0.66 0.63 0.61];

% Multi-energy assets.
caseData.bess.bus = 18;    caseData.bess.Pmax = 0.75; caseData.bess.Emax = 2.40; caseData.bess.E0 = 1.60; caseData.bess.etaCh = 0.95; caseData.bess.etaDis = 0.95;
caseData.el.bus = 30;      caseData.el.Pmax = 0.80;   caseData.el.eta = 0.68;    % MWh_H2/MWh_e
caseData.fc.bus = 30;      caseData.fc.Pmax = 0.70;   caseData.fc.eta = 0.52;    % MWh_e/MWh_H2
caseData.h2.bus = 30;      caseData.h2.Hmax = 6.00;   caseData.h2.H0 = 3.60; caseData.h2.etaCh = 0.995; caseData.h2.etaDis = 0.995;
caseData.h2Demand = zeros(1,caseData.T); caseData.h2Demand(7:22) = 0.06; caseData.h2Demand(17:20) = 0.10;

% Grid, load shedding, and cost parameters.
caseData.gridImportMax = 5.0;
caseData.gridPrice = 1.5*[0.035*ones(1,7),0.075*ones(1,3),0.125*ones(1,5),0.075*ones(1,3),0.125*ones(1,3),0.075*ones(1,2),0.035];
caseData.curtailPenalty = 1500;      % $/MWh weighted by priority
caseData.h2ShedPenalty = 2500;       % $/MWh-H2
caseData.switchCost = 25;            % $ per switching action
caseData.repairCost = 80;            % $ per repaired line-hour action
caseData.h2TerminalValue = 120;      % $/MWh-H2, encourages post-event reserve
caseData.batteryTerminalValue = 80;  % $/MWh

% Restoration crews and repair duration abstraction.
caseData.maxRepairsPerHour = 2;
caseData.bigM = 20;

% Coordinates used only for SCI-style topology visualisation. They follow the
% standard IEEE 33-bus feeder layout approximately and do not affect optimization.
caseData.busXY = [ ...
    0 0; 1 0; 2 0; 3 0; 4 0; 5 0; 6 0; 7 0; 8 0; 9 0; 10 0; 11 0; ...
    12 0; 13 0; 14 0; 15 0; 16 0; 17 0; 2 -1; 3 -1; 4 -1; 5 -1; ...
    3 1; 4 1; 5 1; 6 -1; 7 -1; 8 -1; 9 -1; 10 -1; 11 -1; 12 -1; 13 -1];
end
