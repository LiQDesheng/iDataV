function scenario = build_event_chain(caseData, scenarioName)
%BUILD_EVENT_CHAIN Backward-compatible wrapper for generate_event_chain.
%
% The previous platform called build_event_chain. Section 5 case studies use the
% richer generate_event_chain module, which supports storm, wildfire and ice
% disaster cascading event chains with probabilistic propagation and topology
% fragmentation information.

if nargin < 2, scenarioName = 'storm'; end
switch lower(string(scenarioName))
    case {"severe_wind_line_event", "storm", "severe_storm"}
        scenarioType = 'storm';
    case {"wildfire"}
        scenarioType = 'wildfire';
    case {"ice", "ice_disaster", "ice-disaster"}
        scenarioType = 'ice_disaster';
    otherwise
        scenarioType = 'storm';
end
scenario = generate_event_chain(caseData, scenarioType, struct('seed',2026,'makePlots',false,'resultDir',''));
end
