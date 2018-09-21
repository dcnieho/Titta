#pragma once
#include <string>
#include <tobii_research.h>

std::string TobiiResearchStatusToString     (TobiiResearchStatus trs_);
std::string TobiiResearchStatusToExplanation(TobiiResearchStatus trs_);

std::string TobiiResearchLogSourceToString     (TobiiResearchLogSource trl_);
std::string TobiiResearchLogSourceToExplanation(TobiiResearchLogSource trl_);

std::string TobiiResearchLogLevelToString     (TobiiResearchLogLevel trl_);
std::string TobiiResearchLogLevelToExplanation(TobiiResearchLogLevel trl_);

// the below function is called when an error occurred and application execution should halt
// this function is not defined in this library, it is for the user to implement depending on his platform
void DoExitWithMsg(std::string errMsg_);