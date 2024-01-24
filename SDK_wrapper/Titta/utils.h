#pragma once
#include <string>
#include <memory>
#include <tobii_research.h>
#include <tobii_research_eyetracker.h>
#include <tobii_research_streams.h>

template<typename ... Args>
std::string string_format(char const* const format, Args ... args)
{
    const auto size = static_cast<size_t>(snprintf(nullptr, 0, format, args ...)) + 1; // Extra space for '\0'
    const std::unique_ptr<char[]> buf(new char[size]);
    snprintf(buf.get(), size, format, args ...);
    return std::string(buf.get(), buf.get() + size - 1); // We don't want the '\0' inside
}

std::string TobiiResearchStatusToString     (TobiiResearchStatus trs_);
std::string TobiiResearchStatusToExplanation(TobiiResearchStatus trs_);

std::string TobiiResearchLogSourceToString     (TobiiResearchLogSource trl_);
std::string TobiiResearchLogSourceToExplanation(TobiiResearchLogSource trl_);

std::string TobiiResearchLogLevelToString     (TobiiResearchLogLevel trl_);
std::string TobiiResearchLogLevelToExplanation(TobiiResearchLogLevel trl_);

std::string TobiiResearchStreamErrorToString     (TobiiResearchStreamError trl_);
std::string TobiiResearchStreamErrorToExplanation(TobiiResearchStreamError trl_);

std::string TobiiResearchStreamErrorSourceToString     (TobiiResearchStreamErrorSource trl_);
std::string TobiiResearchStreamErrorSourceToExplanation(TobiiResearchStreamErrorSource trl_);

std::string TobiiResearchNotificationToString     (TobiiResearchNotificationType trl_);
std::string TobiiResearchNotificationToExplanation(TobiiResearchNotificationType trl_);

std::string TobiiResearchEyeImageToString     (TobiiResearchEyeImageType trl_);
std::string TobiiResearchEyeImageToExplanation(TobiiResearchEyeImageType trl_);

std::string TobiiResearchLicenseValidationResultToString     (TobiiResearchLicenseValidationResult trl_);
std::string TobiiResearchLicenseValidationResultToExplanation(TobiiResearchLicenseValidationResult trl_);

// the below function is called when an error occurred and application execution should halt
// this function is not defined in this library, it is for the user to implement depending on his platform
[[ noreturn ]] void DoExitWithMsg(std::string errMsg_);
// this function is used to simply relay a message, it should also be implemented by the user for their platform
void RelayMsg(std::string msg_);

// wrapper around DoExitWithMsg() that nicely formats the Tobii SDK error code
[[ noreturn ]] void ErrorExit(std::string_view errMsg_, TobiiResearchStatus errCode_);