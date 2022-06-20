#define _CRT_SECURE_NO_WARNINGS
#include "Titta/Titta.h"
#include "Titta/utils.h"

#include <iostream>
#include <string>
#include <memory>
#include <variant>
#include <optional>
#include <cstdio>
#include <cinttypes>

#include <pybind11/pybind11.h>
#include <pybind11/stl.h>
#include <pybind11/numpy.h>
namespace py = pybind11;
using namespace pybind11::literals;




template<typename ... Args>
std::string string_format(const std::string& format, Args ... args)
{
    auto size = static_cast<size_t>(snprintf(nullptr, 0, format.c_str(), args ...)) + 1; // Extra space for '\0'
    std::unique_ptr<char[]> buf(new char[size]);
    snprintf(buf.get(), size, format.c_str(), args ...);
    return std::string(buf.get(), buf.get() + size - 1); // We don't want the '\0' inside
}

const char* validityToString(TobiiResearchValidity validity_)
{
    return validity_ == TobiiResearchValidity::TOBII_RESEARCH_VALIDITY_VALID ? "valid" : "invalid";
}
const char* imageTypeToString(TobiiResearchEyeImageType type_)
{
    return type_ == TobiiResearchEyeImageType::TOBII_RESEARCH_EYE_IMAGE_TYPE_FULL ? "full" : (type_ == TobiiResearchEyeImageType::TOBII_RESEARCH_EYE_IMAGE_TYPE_CROPPED ? "cropped" : "unknown");
}
const char* externalSignalChangeTypeToString(TobiiResearchExternalSignalChangeType type_)
{
    return type_ == TobiiResearchExternalSignalChangeType::TOBII_RESEARCH_EXTERNAL_SIGNAL_VALUE_CHANGED ? "value_changed" : (type_ == TobiiResearchExternalSignalChangeType::TOBII_RESEARCH_EXTERNAL_SIGNAL_INITIAL_VALUE ? "initial_value" : "connection_restored");
}
const char* calibrationEyeValidityToString(TobiiResearchCalibrationEyeValidity validity_)
{
    return validity_ == TobiiResearchCalibrationEyeValidity::TOBII_RESEARCH_CALIBRATION_EYE_VALIDITY_INVALID_AND_NOT_USED ? "invalid_and_not_used" : (validity_==TobiiResearchCalibrationEyeValidity::TOBII_RESEARCH_CALIBRATION_EYE_VALIDITY_VALID_BUT_NOT_USED ? "valid_but_not_used" : (validity_==TobiiResearchCalibrationEyeValidity::TOBII_RESEARCH_CALIBRATION_EYE_VALIDITY_VALID_AND_USED ? "valid_and_used" : "unknown"));
}


template <typename T> std::string toString(const T& instance_, std::string spacing="");

template <> std::string toString<>(const TobiiResearchSDKVersion& instance_, std::string spacing)
{
    return string_format("SDK_version %d.%d.%d.%d", instance_.major, instance_.minor, instance_.revision, instance_.build);
}
template <> std::string toString<>(const TobiiTypes::eyeTracker& instance_, std::string spacing)
{
    return string_format("eye_tracker_info for %s (%s)", instance_.model.c_str(), instance_.serialNumber.c_str());
}
template <> std::string toString<>(const TobiiTypes::logMessage& instance_, std::string spacing)
{
    return string_format("log_message (system_time: %" PRId64 ", source: %s, level: %s): %s", instance_.system_time_stamp, TobiiResearchLogSourceToString(instance_.source).c_str(), TobiiResearchLogLevelToString(instance_.level).c_str(), instance_.message.c_str());
}
template <> std::string toString<>(const TobiiTypes::streamErrorMessage& instance_, std::string spacing)
{
    return string_format("stream_error_message (machine: %s, system_time: %" PRId64 ", source: %s, error: %s): %s", instance_.machineSerial.c_str(), instance_.system_time_stamp, TobiiResearchStreamErrorSourceToString(instance_.source).c_str(), TobiiResearchStreamErrorToString(instance_.error).c_str(), instance_.message.c_str());
}

template <> std::string toString<>(const TobiiResearchDisplayArea& instance_, std::string spacing)
{
    return string_format("display_area for %.1fmm x %.1fmm screen", instance_.width, instance_.height);
}

template <> std::string toString<>(const TobiiResearchCalibrationEyeData& instance_, std::string spacing)
{
    return string_format("calibration_eye_data (%s) at [%.4f,%.4f]", calibrationEyeValidityToString(instance_.validity), instance_.position_on_display_area.x, instance_.position_on_display_area.y);
}
template <> std::string toString<>(const TobiiResearchCalibrationSample& instance_, std::string spacing)
{
    auto nextLvl = spacing + "  ";
    return string_format("calibration_sample:\n%sleft: %s\n%sright: %s", nextLvl.c_str(), toString(instance_.left_eye).c_str(), nextLvl.c_str(), toString(instance_.right_eye).c_str());
}
template <> std::string toString<>(const TobiiTypes::CalibrationPoint& instance_, std::string spacing)
{
    int nValidLeft = 0, nValidRight = 0;
    for (auto& sample : instance_.calibration_samples)
    {
        if (sample.left_eye.validity == TobiiResearchCalibrationEyeValidity::TOBII_RESEARCH_CALIBRATION_EYE_VALIDITY_VALID_AND_USED)
            ++nValidLeft;
        if (sample.right_eye.validity == TobiiResearchCalibrationEyeValidity::TOBII_RESEARCH_CALIBRATION_EYE_VALIDITY_VALID_AND_USED)
            ++nValidRight;
    }
    auto ret = string_format("calibration_point at [%.4f,%.4f] with %Iu samples, of which %d valid for left eye and %d valid for right eye", instance_.position_on_display_area.x, instance_.position_on_display_area.y, instance_.calibration_samples.size(), nValidLeft, nValidRight);
#ifndef NDEBUG
    auto nextLvl = spacing + "  ";
    ret += ":\n";
    for (auto& sample : instance_.calibration_samples)
        ret += string_format("%s%s\n", nextLvl.c_str(), toString(sample,nextLvl).c_str());
#endif

    return ret;
}
template <> std::string toString<>(const TobiiTypes::CalibrationResult& instance_, std::string spacing)
{
    std::string pointStr;
    if (!instance_.calibration_points.empty())
    {
        pointStr += string_format(":\n");
        for (auto& point : instance_.calibration_points)
            pointStr += string_format("  %s\n", toString(point, "  ").c_str());
    }
    return string_format("calibration_result for %Iu calibration points%s", instance_.calibration_points.size(), pointStr.c_str());
}

template <> std::string toString<>(const TobiiResearchPoint3D& instance_, std::string spacing)
{
#ifdef NDEBUG
    return string_format("[%.3f,%.3f,%.3f] mm", instance_.x, instance_.y, instance_.z);
#else
    return string_format("<TobiiWrapper.point_3D at [%.3f,%.3f,%.3f] mm>", instance_.x, instance_.y, instance_.z);
#endif
}
template <> std::string toString<>(const TobiiResearchNormalizedPoint2D& instance_, std::string spacing)
{
#ifdef NDEBUG
    return string_format("[%.3f,%.3f] mm", instance_.x, instance_.y);
#else
    return string_format("<TobiiWrapper.point_2D_norm at [%.3f,%.3f] mm>", instance_.x, instance_.y);
#endif
}
template <> std::string toString<>(const TobiiResearchGazePoint& instance_, std::string spacing)
{
    auto nextLvl = spacing + "  ";
#ifdef NDEBUG
    return string_format("(validity: %s)\n%son_display_area: %s\n%sin_user_coordinates: %s", validityToString(instance_.validity), spacing.c_str(), toString(instance_.position_on_display_area, nextLvl).c_str(), spacing.c_str(), toString(instance_.position_in_user_coordinates, nextLvl).c_str());
#else
    return string_format("<TobiiWrapper.gaze_point (validity: %s) containing:\n%son_display_area: %s\n%sin_user_coordinates: %s>", validityToString(instance_.validity), spacing.c_str(), toString(instance_.position_on_display_area, nextLvl).c_str(), spacing.c_str(), toString(instance_.position_in_user_coordinates, nextLvl).c_str());
#endif
}
template <> std::string toString<>(const TobiiResearchPupilData& instance_, std::string spacing)
{
    auto nextLvl = spacing + "  ";
#ifdef NDEBUG
    return string_format("(validity: %s)\n%sdiameter: %.3f mm", validityToString(instance_.validity), nextLvl.c_str(), instance_.diameter);
#else
    return string_format("<TobiiWrapper.pupil_data (validity: %s) containing:\n%sdiameter: %.3f mm>", validityToString(instance_.validity), nextLvl.c_str(), instance_.diameter);
#endif
}
template <> std::string toString<>(const TobiiResearchGazeOrigin& instance_, std::string spacing)
{
    auto nextLvl = spacing + "  ";
#ifdef NDEBUG
    return string_format("(validity: %s)\n%sin_user_coordinates: %s\n%sin_track_box_coordinates: %s", validityToString(instance_.validity), spacing.c_str(), toString(instance_.position_in_user_coordinates, nextLvl).c_str(), spacing.c_str(), toString(instance_.position_in_track_box_coordinates, nextLvl).c_str());
#else
    return string_format("<TobiiWrapper.gaze_origin (validity: %s) containing:\n%sin_user_coordinates: %s\n%sin_track_box_coordinates: %s>", validityToString(instance_.validity), spacing.c_str(), toString(instance_.position_in_user_coordinates, nextLvl).c_str(), spacing.c_str(), toString(instance_.position_in_track_box_coordinates, nextLvl).c_str());
#endif
}
template <> std::string toString<>(const TobiiResearchEyeData& instance_, std::string spacing)
{
    auto nextLvl = spacing + "  ";
#ifdef NDEBUG
    return string_format("\n%sgaze_point: %s\n%spupil: %s\n%sgaze_origin: %s", spacing.c_str(), toString(instance_.gaze_point, nextLvl).c_str(), spacing.c_str(), toString(instance_.pupil_data, nextLvl).c_str(), spacing.c_str(), toString(instance_.gaze_origin, nextLvl).c_str());
#else
    return string_format("<TobiiWrapper.eye_data containing:\n%sgaze_point: %s\n%spupil: %s\n%sgaze_origin: %s>", spacing.c_str(), toString(instance_.gaze_point, nextLvl).c_str(), spacing.c_str(), toString(instance_.pupil_data, nextLvl).c_str(), spacing.c_str(), toString(instance_.gaze_origin, nextLvl).c_str());
#endif
}
template <> std::string toString<>(const TobiiResearchGazeData& instance_, std::string spacing)
{
    auto nextLvl = spacing + "  ";
#ifdef NDEBUG
    return string_format("sample (system_time: %" PRId64 "):\n%sleft: %s\n%sright: %s", instance_.system_time_stamp, spacing.c_str(), toString(instance_.left_eye, nextLvl).c_str(), spacing.c_str(), toString(instance_.right_eye, nextLvl).c_str());
#else
    return string_format("<TobiiWrapper.gaze_data (system_time: %" PRId64 ") containing:\n%sleft: %s\n%sright: %s>", instance_.system_time_stamp, spacing.c_str(), toString(instance_.left_eye, nextLvl).c_str(), spacing.c_str(), toString(instance_.right_eye, nextLvl).c_str());
#endif
}

template <> std::string toString<>(const TobiiTypes::eyeImage& instance_, std::string spacing)
{
    return string_format("%s image taken at system_time: %" PRId64 " with camera %d, %dbit, %dx%d", imageTypeToString(instance_.type), instance_.system_time_stamp, instance_.camera_id, instance_.bits_per_pixel, instance_.width, instance_.height);
}

template <> std::string toString<>(const TobiiResearchExternalSignalData& instance_, std::string spacing)
{
    return string_format("external signal arrived at system_time: %" PRId64 ", type: %s, value: %d", instance_.system_time_stamp, externalSignalChangeTypeToString(instance_.change_type), instance_.value);
}

template <> std::string toString<>(const TobiiResearchTimeSynchronizationData& instance_, std::string spacing)
{
    return string_format("time sync system_request_time_stamp: %" PRId64 ", device_time_stamp: %" PRId64 ", system_response_time_stamp: %" PRId64 "", instance_.system_request_time_stamp, instance_.device_time_stamp, instance_.system_response_time_stamp);
}

template <> std::string toString<>(const TobiiResearchEyeUserPositionGuide& instance_, std::string spacing)
{
    auto nextLvl = spacing + "  ";
#ifdef NDEBUG
    return string_format("(validity: %s)\n%suser_position: %s", validityToString(instance_.validity), spacing.c_str(), toString(instance_.user_position, nextLvl).c_str());
#else
    return string_format("<TobiiWrapper.positioning_eye (validity: %s) containing:\n%suser_position: %s>", validityToString(instance_.validity), spacing.c_str(), toString(instance_.user_position, nextLvl).c_str());
#endif
}
template <> std::string toString<>(const TobiiResearchUserPositionGuide& instance_, std::string spacing)
{
    auto nextLvl = spacing + "  ";
#ifdef NDEBUG
    return string_format("positioning:\n%sleft: %s\n%sright: %s", spacing.c_str(), toString(instance_.left_eye, nextLvl).c_str(), spacing.c_str(), toString(instance_.right_eye, nextLvl).c_str());
#else
    return string_format("<TobiiWrapper.positioning containing:\n%sleft: %s\n%sright: %s>", spacing.c_str(), toString(instance_.left_eye, nextLvl).c_str(), spacing.c_str(), toString(instance_.right_eye, nextLvl).c_str());
#endif
}


py::array_t<uint8_t> imageToNumpy(const TobiiTypes::eyeImage e_)
{
    py::array_t<uint8_t> a;
    a.resize({ e_.height, e_.width });
    std::memcpy(a.mutable_data(), e_.data(), e_.data_size);
    return a;
}

std::vector<std::string> convertCapabilities(const TobiiResearchCapabilities data_)
{
    std::vector<std::string> out;

    if (data_ & TOBII_RESEARCH_CAPABILITIES_CAN_SET_DISPLAY_AREA)
        out.emplace_back("can_set_display_area");
    if (data_ & TOBII_RESEARCH_CAPABILITIES_HAS_EXTERNAL_SIGNAL)
        out.emplace_back("has_external_signal");
    if (data_ & TOBII_RESEARCH_CAPABILITIES_HAS_EYE_IMAGES)
        out.emplace_back("has_eye_images");
    if (data_ & TOBII_RESEARCH_CAPABILITIES_HAS_GAZE_DATA)
        out.emplace_back("has_gaze_data");
    if (data_ & TOBII_RESEARCH_CAPABILITIES_HAS_HMD_GAZE_DATA)
        out.emplace_back("has_HMD_gaze_data");
    if (data_ & TOBII_RESEARCH_CAPABILITIES_CAN_DO_SCREEN_BASED_CALIBRATION)
        out.emplace_back("can_do_screen_based_calibration");
    if (data_ & TOBII_RESEARCH_CAPABILITIES_CAN_DO_HMD_BASED_CALIBRATION)
        out.emplace_back("can_do_HMD_based_calibration");
    if (data_ & TOBII_RESEARCH_CAPABILITIES_HAS_HMD_LENS_CONFIG)
        out.emplace_back("has_HMD_lens_config");
    if (data_ & TOBII_RESEARCH_CAPABILITIES_CAN_DO_MONOCULAR_CALIBRATION)
        out.emplace_back("can_do_monocular_calibration");

    return out;
}


// start module scope
PYBIND11_MODULE(TobiiWrapper, m)
{
    // SDK and eye tracker info
    py::class_<TobiiResearchSDKVersion>(m, "SDK_version")
        .def_readwrite("major", &TobiiResearchSDKVersion::major)
        .def_readwrite("minor", &TobiiResearchSDKVersion::minor)
        .def_readwrite("revision", &TobiiResearchSDKVersion::revision)
        .def_readwrite("build", &TobiiResearchSDKVersion::build)
        .def(py::pickle(
            [](const TobiiResearchSDKVersion& p) { // __getstate__
                return py::make_tuple(p.major, p.minor, p.revision, p.build);
            },
            [](py::tuple t) { // __setstate__
                if (t.size() != 4)
                    throw std::runtime_error("Invalid state!");

                TobiiResearchSDKVersion p{ t[0].cast<int>(),t[1].cast<int>(),t[2].cast<int>(),t[3].cast<int>() };
                return p;
            }
        ))
        .def("__repr__", [](const TobiiResearchSDKVersion& instance_) { return toString(instance_); })
        ;
    py::class_<TobiiTypes::eyeTracker>(m, "eye_tracker_info")
        .def_readwrite("device_name", &TobiiTypes::eyeTracker::deviceName)
        .def_readwrite("serial_number", &TobiiTypes::eyeTracker::serialNumber)
        .def_readwrite("model", &TobiiTypes::eyeTracker::model)
        .def_readwrite("firmware_version", &TobiiTypes::eyeTracker::firmwareVersion)
        .def_readwrite("runtime_version", &TobiiTypes::eyeTracker::runtimeVersion)
        .def_readwrite("address", &TobiiTypes::eyeTracker::address)
        .def_readwrite("frequency", &TobiiTypes::eyeTracker::frequency)
        .def_readwrite("tracking_mode", &TobiiTypes::eyeTracker::trackingMode)
        .def_property_readonly("capabilities", &convertCapabilities)
        .def_readwrite("supported_frequencies", &TobiiTypes::eyeTracker::supportedFrequencies)
        .def_readwrite("supported_modes", &TobiiTypes::eyeTracker::supportedModes)
        .def(py::pickle(
            [](const TobiiTypes::eyeTracker& p) { // __getstate__
                return py::make_tuple(p.deviceName, p.serialNumber, p.model, p.firmwareVersion, p.runtimeVersion, p.address, p.frequency, p.trackingMode, p.capabilities, p.supportedFrequencies, p.supportedModes);
            },
            [](py::tuple t) { // __setstate__
                if (t.size() != 11)
                    throw std::runtime_error("Invalid state!");

                TobiiTypes::eyeTracker p{ t[0].cast<std::string>(),t[1].cast<std::string>(),t[2].cast<std::string>(),t[3].cast<std::string>(),t[4].cast<std::string>(),t[5].cast<std::string>(),t[6].cast<float>(),t[7].cast<std::string>(),t[8].cast<TobiiResearchCapabilities>(),t[9].cast<std::vector<float>>(),t[10].cast<std::vector<std::string>>() };
                return p;
            }
        ))
        .def("__repr__", [](const TobiiTypes::eyeTracker& instance_) { return toString(instance_); })
        ;

    // logging
    py::enum_<TobiiResearchLogSource>(m, "log_source")
        .value("stream_engine", TobiiResearchLogSource::TOBII_RESEARCH_LOG_SOURCE_STREAM_ENGINE)
        .value("SDK", TobiiResearchLogSource::TOBII_RESEARCH_LOG_SOURCE_SDK)
        .value("firmware_upgrade", TobiiResearchLogSource::TOBII_RESEARCH_LOG_SOURCE_FIRMWARE_UPGRADE)
        .export_values()
        ;
    py::enum_<TobiiResearchLogLevel>(m, "log_level")
        .value("error", TobiiResearchLogLevel::TOBII_RESEARCH_LOG_LEVEL_ERROR)
        .value("warning", TobiiResearchLogLevel::TOBII_RESEARCH_LOG_LEVEL_WARNING)
        .value("information", TobiiResearchLogLevel::TOBII_RESEARCH_LOG_LEVEL_INFORMATION)
        .value("debug", TobiiResearchLogLevel::TOBII_RESEARCH_LOG_LEVEL_DEBUG)
        .value("trace", TobiiResearchLogLevel::TOBII_RESEARCH_LOG_LEVEL_TRACE)
        .export_values()
        ;
    py::class_<TobiiTypes::logMessage>(m, "log_message")
        .def_readwrite("system_time_stamp", &TobiiTypes::logMessage::system_time_stamp)
        .def_readwrite("source", &TobiiTypes::logMessage::source)
        .def_readwrite("level", &TobiiTypes::logMessage::level)
        .def_readwrite("message", &TobiiTypes::logMessage::message)
        .def(py::pickle(
            [](const TobiiTypes::logMessage& p) { // __getstate__
                return py::make_tuple(p.system_time_stamp, p.source, p.level, p.message);
            },
            [](py::tuple t) { // __setstate__
                if (t.size() != 4)
                    throw std::runtime_error("Invalid state!");

                TobiiTypes::logMessage p{ t[0].cast<int64_t>(),t[1].cast<TobiiResearchLogSource>(),t[2].cast<TobiiResearchLogLevel>(),t[3].cast<std::string>() };
                return p;
            }
        ))
        .def("__repr__", [](const TobiiTypes::logMessage& instance_) { return toString(instance_); })
        ;
    py::enum_<TobiiResearchStreamError>(m, "stream_error")
        .value("connection_lost", TobiiResearchStreamError::TOBII_RESEARCH_STREAM_ERROR_CONNECTION_LOST)
        .value("insufficient_license", TobiiResearchStreamError::TOBII_RESEARCH_STREAM_ERROR_INSUFFICIENT_LICENSE)
        .value("not_supported", TobiiResearchStreamError::TOBII_RESEARCH_STREAM_ERROR_NOT_SUPPORTED)
        .value("too_many_subscribers", TobiiResearchStreamError::TOBII_RESEARCH_STREAM_ERROR_TOO_MANY_SUBSCRIBERS)
        .value("internal_error", TobiiResearchStreamError::TOBII_RESEARCH_STREAM_ERROR_INTERNAL_ERROR)
        .value("user_error", TobiiResearchStreamError::TOBII_RESEARCH_STREAM_ERROR_USER_ERROR)
        .export_values()
        ;
    py::enum_<TobiiResearchStreamErrorSource>(m, "stream_error_source")
        .value("user", TobiiResearchStreamErrorSource::TOBII_RESEARCH_STREAM_ERROR_SOURCE_USER)
        .value("stream_pump", TobiiResearchStreamErrorSource::TOBII_RESEARCH_STREAM_ERROR_SOURCE_STREAM_PUMP)
        .value("subscription_gaze_data", TobiiResearchStreamErrorSource::TOBII_RESEARCH_STREAM_ERROR_SOURCE_SUBSCRIPTION_GAZE_DATA)
        .value("subscription_external_signal", TobiiResearchStreamErrorSource::TOBII_RESEARCH_STREAM_ERROR_SOURCE_SUBSCRIPTION_EXTERNAL_SIGNAL)
        .value("subscription_time_synchronization_data", TobiiResearchStreamErrorSource::TOBII_RESEARCH_STREAM_ERROR_SOURCE_SUBSCRIPTION_TIME_SYNCHRONIZATION_DATA)
        .value("subscription_eye_image", TobiiResearchStreamErrorSource::TOBII_RESEARCH_STREAM_ERROR_SOURCE_SUBSCRIPTION_EYE_IMAGE)
        .value("subscription_notification", TobiiResearchStreamErrorSource::TOBII_RESEARCH_STREAM_ERROR_SOURCE_SUBSCRIPTION_NOTIFICATION)
        .value("subscription_HMD_gaze_data", TobiiResearchStreamErrorSource::TOBII_RESEARCH_STREAM_ERROR_SOURCE_SUBSCRIPTION_HMD_GAZE_DATA)
        .value("subscription_user_position_guide", TobiiResearchStreamErrorSource::TOBII_RESEARCH_STREAM_ERROR_SOURCE_SUBSCRIPTION_USER_POSITION_GUIDE)
        .export_values()
        ;
    py::class_<TobiiTypes::streamErrorMessage>(m, "stream_error_message")
        .def_readwrite("machine_serial", &TobiiTypes::streamErrorMessage::machineSerial)
        .def_readwrite("system_time_stamp", &TobiiTypes::streamErrorMessage::system_time_stamp)
        .def_readwrite("error", &TobiiTypes::streamErrorMessage::error)
        .def_readwrite("source", &TobiiTypes::streamErrorMessage::source)
        .def_readwrite("message", &TobiiTypes::streamErrorMessage::message)
        .def(py::pickle(
            [](const TobiiTypes::streamErrorMessage& p) { // __getstate__
                return py::make_tuple(p.machineSerial, p.system_time_stamp, p.error, p.source, p.message);
            },
            [](py::tuple t) { // __setstate__
                if (t.size() != 5)
                    throw std::runtime_error("Invalid state!");

                TobiiTypes::streamErrorMessage p{ t[0].cast<std::string>(),t[1].cast<int64_t>(),t[2].cast<TobiiResearchStreamError>(),t[3].cast<TobiiResearchStreamErrorSource>(),t[4].cast<std::string>() };
                return p;
            }
        ))
        .def("__repr__", [](const TobiiTypes::streamErrorMessage& instance_) { return toString(instance_); })
        ;

    // getters and setters
    py::class_<TobiiResearchTrackBox>(m, "track_box")
        .def_readwrite("back_lower_left", &TobiiResearchTrackBox::back_lower_left)
        .def_readwrite("back_lower_right", &TobiiResearchTrackBox::back_lower_right)
        .def_readwrite("back_upper_left", &TobiiResearchTrackBox::back_upper_left)
        .def_readwrite("back_upper_right", &TobiiResearchTrackBox::back_upper_right)
        .def_readwrite("front_lower_left", &TobiiResearchTrackBox::front_lower_left)
        .def_readwrite("front_lower_right", &TobiiResearchTrackBox::front_lower_right)
        .def_readwrite("front_upper_left", &TobiiResearchTrackBox::front_upper_left)
        .def_readwrite("front_upper_right", &TobiiResearchTrackBox::front_upper_right)
        .def(py::pickle(
            [](const TobiiResearchTrackBox& p) { // __getstate__
                return py::make_tuple(p.back_lower_left, p.back_lower_right, p.back_upper_left, p.back_upper_right, p.front_lower_left, p.front_lower_right, p.front_upper_left, p.front_upper_right);
            },
            [](py::tuple t) { // __setstate__
                if (t.size() != 8)
                    throw std::runtime_error("Invalid state!");

                TobiiResearchTrackBox p{ t[0].cast<TobiiResearchPoint3D>(),t[1].cast<TobiiResearchPoint3D>(),t[2].cast<TobiiResearchPoint3D>(),t[3].cast<TobiiResearchPoint3D>(),t[4].cast<TobiiResearchPoint3D>(),t[5].cast<TobiiResearchPoint3D>(),t[6].cast<TobiiResearchPoint3D>(),t[7].cast<TobiiResearchPoint3D>() };
                return p;
            }
        ))
        // default is fine for this one
        //.def("__repr__", [](const TobiiResearchTrackBox& instance_) { return toString(instance_); })
        ;
    py::class_<TobiiResearchDisplayArea>(m, "display_area")
        .def_readwrite("bottom_left", &TobiiResearchDisplayArea::bottom_left)
        .def_readwrite("bottom_right", &TobiiResearchDisplayArea::bottom_right)
        .def_readwrite("height", &TobiiResearchDisplayArea::height)
        .def_readwrite("top_left", &TobiiResearchDisplayArea::top_left)
        .def_readwrite("top_right", &TobiiResearchDisplayArea::top_right)
        .def_readwrite("width", &TobiiResearchDisplayArea::width)
        .def(py::pickle(
            [](const TobiiResearchDisplayArea& p) { // __getstate__
                return py::make_tuple(p.bottom_left, p.bottom_right, p.height, p.top_left, p.top_right, p.width);
            },
            [](py::tuple t) { // __setstate__
                if (t.size() != 6)
                    throw std::runtime_error("Invalid state!");

                TobiiResearchDisplayArea p{ t[0].cast<TobiiResearchPoint3D>(),t[1].cast<TobiiResearchPoint3D>(),t[2].cast<float>(),t[3].cast<TobiiResearchPoint3D>(),t[4].cast<TobiiResearchPoint3D>(),t[5].cast<float>() };
                return p;
            }
        ))
        .def("__repr__", [](const TobiiResearchDisplayArea& instance_) { return toString(instance_); })
        ;
    py::enum_<TobiiResearchLicenseValidationResult>(m, "license_validation_result")
        .value("ok", TobiiResearchLicenseValidationResult::TOBII_RESEARCH_LICENSE_VALIDATION_RESULT_OK)
        .value("tampered", TobiiResearchLicenseValidationResult::TOBII_RESEARCH_LICENSE_VALIDATION_RESULT_TAMPERED)
        .value("invalid_application_signature", TobiiResearchLicenseValidationResult::TOBII_RESEARCH_LICENSE_VALIDATION_RESULT_INVALID_APPLICATION_SIGNATURE)
        .value("nonsigned_application", TobiiResearchLicenseValidationResult::TOBII_RESEARCH_LICENSE_VALIDATION_RESULT_NONSIGNED_APPLICATION)
        .value("expired", TobiiResearchLicenseValidationResult::TOBII_RESEARCH_LICENSE_VALIDATION_RESULT_EXPIRED)
        .value("premature", TobiiResearchLicenseValidationResult::TOBII_RESEARCH_LICENSE_VALIDATION_RESULT_PREMATURE)
        .value("invalid_process_name", TobiiResearchLicenseValidationResult::TOBII_RESEARCH_LICENSE_VALIDATION_RESULT_INVALID_PROCESS_NAME)
        .value("invalid_serial_number", TobiiResearchLicenseValidationResult::TOBII_RESEARCH_LICENSE_VALIDATION_RESULT_INVALID_SERIAL_NUMBER)
        .value("invalid_model", TobiiResearchLicenseValidationResult::TOBII_RESEARCH_LICENSE_VALIDATION_RESULT_INVALID_MODEL)
        .value("unknown", TobiiResearchLicenseValidationResult::TOBII_RESEARCH_LICENSE_VALIDATION_RESULT_UNKNOWN)
        .export_values()
        ;

    // calibration
    py::enum_<TobiiTypes::CalibrationState>(m, "calibration_state")
        .value("not_yet_entered", TobiiTypes::CalibrationState::NotYetEntered)
        .value("awaiting_cal_point", TobiiTypes::CalibrationState::AwaitingCalPoint)
        .value("collecting_data", TobiiTypes::CalibrationState::CollectingData)
        .value("discarding_data", TobiiTypes::CalibrationState::DiscardingData)
        .value("computing", TobiiTypes::CalibrationState::Computing)
        .value("getting_calibration_data", TobiiTypes::CalibrationState::GettingCalibrationData)
        .value("applying_calibration_data", TobiiTypes::CalibrationState::ApplyingCalibrationData)
        .value("left", TobiiTypes::CalibrationState::Left)
        .export_values()
        ;
    py::enum_<TobiiTypes::CalibrationAction>(m, "calibration_action")
        .value("nothing", TobiiTypes::CalibrationAction::Nothing)
        .value("enter", TobiiTypes::CalibrationAction::Enter)
        .value("collect_data", TobiiTypes::CalibrationAction::CollectData)
        .value("discard_data", TobiiTypes::CalibrationAction::DiscardData)
        .value("compute", TobiiTypes::CalibrationAction::Compute)
        .value("get_calibration_data", TobiiTypes::CalibrationAction::GetCalibrationData)
        .value("apply_calibration_data", TobiiTypes::CalibrationAction::ApplyCalibrationData)
        .value("exit", TobiiTypes::CalibrationAction::Exit)
        .export_values()
        ;
    py::enum_<TobiiResearchCalibrationStatus>(m, "calibration_status")
        .value("failure", TobiiResearchCalibrationStatus::TOBII_RESEARCH_CALIBRATION_FAILURE)
        .value("success", TobiiResearchCalibrationStatus::TOBII_RESEARCH_CALIBRATION_SUCCESS)
        .value("success_left_eye", TobiiResearchCalibrationStatus::TOBII_RESEARCH_CALIBRATION_SUCCESS_LEFT_EYE)
        .value("success_right_eye", TobiiResearchCalibrationStatus::TOBII_RESEARCH_CALIBRATION_SUCCESS_RIGHT_EYE)
        .export_values()
        ;
    py::enum_<TobiiResearchSelectedEye>(m, "selected_eye")
        .value("left", TobiiResearchSelectedEye::TOBII_RESEARCH_SELECTED_EYE_LEFT)
        .value("right", TobiiResearchSelectedEye::TOBII_RESEARCH_SELECTED_EYE_RIGHT)
        .value("both", TobiiResearchSelectedEye::TOBII_RESEARCH_SELECTED_EYE_BOTH)
        .export_values()
        ;
    py::enum_<TobiiResearchCalibrationEyeValidity>(m, "calibration_eye_validity")
        .value("invalid_and_not_used", TobiiResearchCalibrationEyeValidity::TOBII_RESEARCH_CALIBRATION_EYE_VALIDITY_INVALID_AND_NOT_USED)
        .value("valid_but_not_used", TobiiResearchCalibrationEyeValidity::TOBII_RESEARCH_CALIBRATION_EYE_VALIDITY_VALID_BUT_NOT_USED)
        .value("valid_and_used", TobiiResearchCalibrationEyeValidity::TOBII_RESEARCH_CALIBRATION_EYE_VALIDITY_VALID_AND_USED)
        .value("unknown", TobiiResearchCalibrationEyeValidity::TOBII_RESEARCH_CALIBRATION_EYE_VALIDITY_UNKNOWN)
        .export_values()
        ;
    py::class_<TobiiResearchCalibrationEyeData>(m, "calibration_eye_data")
        .def_readwrite("position_on_display_area", &TobiiResearchCalibrationEyeData::position_on_display_area)
        .def_readwrite("validity", &TobiiResearchCalibrationEyeData::validity)
        .def(py::pickle(
            [](const TobiiResearchCalibrationEyeData& p) { // __getstate__
                return py::make_tuple(p.position_on_display_area, p.validity);
            },
            [](py::tuple t) { // __setstate__
                if (t.size() != 2)
                    throw std::runtime_error("Invalid state!");

                TobiiResearchCalibrationEyeData p{ t[0].cast<TobiiResearchNormalizedPoint2D>(), t[1].cast<TobiiResearchCalibrationEyeValidity>() };
                return p;
            }
        ))
        .def("__repr__", [](const TobiiResearchCalibrationEyeData& instance_) { return toString(instance_); })
        ;
    py::class_<TobiiResearchCalibrationSample>(m, "calibration_sample")
        .def_readwrite("left", &TobiiResearchCalibrationSample::left_eye)
        .def_readwrite("right", &TobiiResearchCalibrationSample::right_eye)
        .def(py::pickle(
            [](const TobiiResearchCalibrationSample& p) { // __getstate__
                return py::make_tuple(p.left_eye, p.right_eye);
            },
            [](py::tuple t) { // __setstate__
                if (t.size() != 2)
                    throw std::runtime_error("Invalid state!");

                TobiiResearchCalibrationSample p{ t[0].cast<TobiiResearchCalibrationEyeData>(), t[1].cast<TobiiResearchCalibrationEyeData>() };
                return p;
            }
        ))
        .def("__repr__", [](const TobiiResearchCalibrationSample& instance_) { return toString(instance_); })
        ;
    py::class_<TobiiTypes::CalibrationPoint>(m, "calibration_point")
        .def_readwrite("position_on_display_area", &TobiiTypes::CalibrationPoint::position_on_display_area)
        .def_readwrite("samples", &TobiiTypes::CalibrationPoint::calibration_samples)
        .def(py::pickle(
            [](const TobiiTypes::CalibrationPoint& p) { // __getstate__
                return py::make_tuple(p.position_on_display_area, p.calibration_samples);
            },
            [](py::tuple t) { // __setstate__
                if (t.size() != 2)
                    throw std::runtime_error("Invalid state!");

                TobiiTypes::CalibrationPoint p{ t[0].cast<TobiiResearchNormalizedPoint2D>(), t[1].cast<std::vector<TobiiResearchCalibrationSample>>() };
                return p;
            }
        ))
        .def("__repr__", [](const TobiiTypes::CalibrationPoint& instance_) { return toString(instance_); })
        ;
    py::class_<TobiiTypes::CalibrationResult>(m, "calibration_result")
        .def_readwrite("points", &TobiiTypes::CalibrationResult::calibration_points)
        .def_readwrite("status", &TobiiTypes::CalibrationResult::status)
        .def(py::pickle(
            [](const TobiiTypes::CalibrationResult& p) { // __getstate__
                return py::make_tuple(p.calibration_points, p.status);
            },
            [](py::tuple t) { // __setstate__
                if (t.size() != 2)
                    throw std::runtime_error("Invalid state!");

                TobiiTypes::CalibrationResult p{ t[0].cast<std::vector<TobiiTypes::CalibrationPoint>>(), t[1].cast<TobiiResearchCalibrationStatus>() };
                return p;
            }
        ))
        .def("__repr__", [](const TobiiTypes::CalibrationResult& instance_) { return toString(instance_); })
        ;
    py::class_<TobiiTypes::CalibrationWorkItem>(m, "calibration_work_item")
        .def_readwrite("action", &TobiiTypes::CalibrationWorkItem::action)
        .def_readwrite("coordinates", &TobiiTypes::CalibrationWorkItem::coordinates)
        .def_readwrite("eye", &TobiiTypes::CalibrationWorkItem::eye)
        .def_readwrite("calibration_data", &TobiiTypes::CalibrationWorkItem::calibrationData)
        .def(py::pickle(
            [](const TobiiTypes::CalibrationWorkItem& p) { // __getstate__
                return py::make_tuple(p.action, p.coordinates, p.eye, p.calibrationData);
            },
            [](py::tuple t) { // __setstate__
                if (t.size() != 4)
                    throw std::runtime_error("Invalid state!");

                TobiiTypes::CalibrationWorkItem p{ t[0].cast<TobiiTypes::CalibrationAction>(),t[1].cast<std::optional<std::vector<double>>>(),t[2].cast<std::optional<std::string>>(),t[3].cast<std::optional<std::vector<uint8_t>>>() };
                return p;
            }
        ))
        ;
    py::class_<TobiiTypes::CalibrationWorkResult>(m, "calibration_work_result")
        .def_readwrite("work_item", &TobiiTypes::CalibrationWorkResult::workItem)
        .def_property_readonly("status", [](TobiiTypes::CalibrationWorkResult& instance_) { return static_cast<int>(instance_.status); })
        .def_readwrite("status_string", &TobiiTypes::CalibrationWorkResult::statusString)
        .def_readwrite("calibration_result", &TobiiTypes::CalibrationWorkResult::calibrationResult)
        .def_readwrite("calibration_data", &TobiiTypes::CalibrationWorkResult::calibrationData)
        .def(py::pickle(
            [](const TobiiTypes::CalibrationWorkResult& p) { // __getstate__
                return py::make_tuple(p.workItem, static_cast<int>(p.status), p.statusString, p.calibrationResult, p.calibrationData);
            },
            [](py::tuple t) { // __setstate__
                if (t.size() != 5)
                    throw std::runtime_error("Invalid state!");

                TobiiTypes::CalibrationWorkResult p{ t[0].cast<TobiiTypes::CalibrationWorkItem>(),static_cast<TobiiResearchStatus>(t[1].cast<int>()),t[2].cast<std::string>(),t[3].cast<std::optional<TobiiTypes::CalibrationResult>>(),t[4].cast<std::optional<std::vector<uint8_t>>>() };
                return p;
            }
        ))
        ;
    

    // gaze
    py::enum_<TobiiResearchValidity>(m, "validity")
        .value("invalid", TobiiResearchValidity::TOBII_RESEARCH_VALIDITY_INVALID)
        .value("valid", TobiiResearchValidity::TOBII_RESEARCH_VALIDITY_VALID)
        .export_values()
        ;
    py::class_<TobiiResearchPoint3D>(m, "point_3D")
        .def_readwrite("x", &TobiiResearchPoint3D::x)
        .def_readwrite("y", &TobiiResearchPoint3D::y)
        .def_readwrite("z", &TobiiResearchPoint3D::z)
        .def(py::pickle(
            [](const TobiiResearchPoint3D& p) { // __getstate__
                return py::make_tuple(p.x, p.y, p.z);
            },
            [](py::tuple t) { // __setstate__
                if (t.size() != 3)
                    throw std::runtime_error("Invalid state!");

                TobiiResearchPoint3D p{ t[0].cast<float>(),t[1].cast<float>(),t[2].cast<float>() };
                return p;
            }
        ))
        .def("__repr__",[](const TobiiResearchPoint3D& instance_){ return toString(instance_); })
        ;
    py::class_<TobiiResearchNormalizedPoint2D>(m, "point_2D_norm")
        .def_readwrite("x", &TobiiResearchNormalizedPoint2D::x)
        .def_readwrite("y", &TobiiResearchNormalizedPoint2D::y)
        .def(py::pickle(
            [](const TobiiResearchNormalizedPoint2D& p) { // __getstate__
                return py::make_tuple(p.x, p.y);
            },
            [](py::tuple t) { // __setstate__
                if (t.size() != 2)
                    throw std::runtime_error("Invalid state!");

                TobiiResearchNormalizedPoint2D p{ t[0].cast<float>(),t[1].cast<float>() };
                return p;
            }
        ))
        .def("__repr__",[](const TobiiResearchNormalizedPoint2D& instance_){ return toString(instance_); })
        ;
    py::class_<TobiiResearchGazePoint>(m, "gaze_point")
        .def_readwrite("on_display_area", &TobiiResearchGazePoint::position_on_display_area)
        .def_readwrite("in_user_coordinates", &TobiiResearchGazePoint::position_in_user_coordinates)
        .def_readwrite("validity", &TobiiResearchGazePoint::validity)
        .def(py::pickle(
            [](const TobiiResearchGazePoint& p) { // __getstate__
                return py::make_tuple(p.position_on_display_area, p.position_in_user_coordinates, p.validity);
            },
            [](py::tuple t) { // __setstate__
                if (t.size() != 3)
                    throw std::runtime_error("Invalid state!");

                TobiiResearchGazePoint p{ t[0].cast<TobiiResearchNormalizedPoint2D>(),t[1].cast<TobiiResearchPoint3D>(),t[2].cast<TobiiResearchValidity>() };
                return p;
            }
        ))
        .def("__repr__", [](const TobiiResearchGazePoint& instance_){ return toString(instance_); })
        ;
    py::class_<TobiiResearchPupilData>(m, "pupil_data")
        .def_readwrite("diameter", &TobiiResearchPupilData::diameter)
        .def_readwrite("validity", &TobiiResearchPupilData::validity)
        .def(py::pickle(
            [](const TobiiResearchPupilData& p) { // __getstate__
                return py::make_tuple(p.diameter, p.validity);
            },
            [](py::tuple t) { // __setstate__
                if (t.size() != 2)
                    throw std::runtime_error("Invalid state!");

                TobiiResearchPupilData p{ t[0].cast<float>(),t[1].cast<TobiiResearchValidity>() };
                return p;
            }
        ))
        .def("__repr__",[](const TobiiResearchPupilData& instance_){ return toString(instance_); })
        ;
    py::class_<TobiiResearchGazeOrigin>(m, "gaze_origin")
        .def_readwrite("in_user_coordinates", &TobiiResearchGazeOrigin::position_in_user_coordinates)
        .def_readwrite("in_track_box_coordinates", &TobiiResearchGazeOrigin::position_in_track_box_coordinates)
        .def_readwrite("validity", &TobiiResearchGazeOrigin::validity)
        .def(py::pickle(
            [](const TobiiResearchGazeOrigin& p) { // __getstate__
                return py::make_tuple(p.position_in_user_coordinates, p.position_in_track_box_coordinates, p.validity);
            },
            [](py::tuple t) { // __setstate__
                if (t.size() != 3)
                    throw std::runtime_error("Invalid state!");

                TobiiResearchGazeOrigin p{ t[0].cast<TobiiResearchPoint3D>(),t[1].cast<TobiiResearchPoint3D>(),t[2].cast<TobiiResearchValidity>() };
                return p;
            }
        ))
        .def("__repr__", [](const TobiiResearchGazeOrigin& instance_){ return toString(instance_); })
        ;
    py::class_<TobiiResearchEyeData>(m, "eye_data")
        .def_readwrite("gaze_point", &TobiiResearchEyeData::gaze_point)
        .def_readwrite("pupil", &TobiiResearchEyeData::pupil_data)
        .def_readwrite("gaze_origin", &TobiiResearchEyeData::gaze_origin)
        .def(py::pickle(
            [](const TobiiResearchEyeData& p) { // __getstate__
                return py::make_tuple(p.gaze_point, p.pupil_data, p.gaze_origin);
            },
            [](py::tuple t) { // __setstate__
                if (t.size() != 3)
                    throw std::runtime_error("Invalid state!");

                TobiiResearchEyeData p{ t[0].cast<TobiiResearchGazePoint>(),t[1].cast<TobiiResearchPupilData>(),t[2].cast<TobiiResearchGazeOrigin>() };
                return p;
            }
        ))
        .def("__repr__", [](const TobiiResearchEyeData& instance_){ return toString(instance_); })
        ;
    py::class_<TobiiResearchGazeData>(m, "gaze_data")
        .def_readwrite("left", &TobiiResearchGazeData::left_eye)
        .def_readwrite("right", &TobiiResearchGazeData::right_eye)
        .def_readwrite("device_time_stamp", &TobiiResearchGazeData::device_time_stamp)
        .def_readwrite("system_time_stamp", &TobiiResearchGazeData::system_time_stamp)
        .def(py::pickle(
            [](const TobiiResearchGazeData& p) { // __getstate__
                return py::make_tuple(p.left_eye, p.right_eye, p.device_time_stamp, p.system_time_stamp);
            },
            [](py::tuple t) { // __setstate__
                if (t.size() != 4)
                    throw std::runtime_error("Invalid state!");

                TobiiResearchGazeData p{ t[0].cast<TobiiResearchEyeData>(),t[1].cast<TobiiResearchEyeData>(),t[2].cast<int64_t>(),t[3].cast<int64_t>() };
                return p;
            }
        ))
        .def("__repr__", [](const TobiiResearchGazeData& instance_){ return toString(instance_); })
        ;


    // eye images
    py::enum_<TobiiResearchEyeImageType>(m, "eye_image_type")
        .value("full_image", TobiiResearchEyeImageType::TOBII_RESEARCH_EYE_IMAGE_TYPE_FULL)
        .value("cropped_image", TobiiResearchEyeImageType::TOBII_RESEARCH_EYE_IMAGE_TYPE_CROPPED)
        .value("multi_roi_image", TobiiResearchEyeImageType::TOBII_RESEARCH_EYE_IMAGE_TYPE_MULTI_ROI)
        .value("unknown", TobiiResearchEyeImageType::TOBII_RESEARCH_EYE_IMAGE_TYPE_UNKNOWN)
        .export_values();
    py::class_<TobiiTypes::eyeImage>(m, "eye_image")
        .def_readwrite("is_gif", &TobiiTypes::eyeImage::isGif)
        .def_readwrite("device_time_stamp", &TobiiTypes::eyeImage::device_time_stamp)
        .def_readwrite("system_time_stamp", &TobiiTypes::eyeImage::system_time_stamp)
        .def_readwrite("bits_per_pixel", &TobiiTypes::eyeImage::bits_per_pixel)
        .def_readwrite("padding_per_pixel", &TobiiTypes::eyeImage::padding_per_pixel)
        .def_readwrite("width", &TobiiTypes::eyeImage::width)
        .def_readwrite("height", &TobiiTypes::eyeImage::height)
        .def_readwrite("region_id", &TobiiTypes::eyeImage::region_id)
        .def_readwrite("region_top", &TobiiTypes::eyeImage::region_top)
        .def_readwrite("region_left", &TobiiTypes::eyeImage::region_left)
        .def_readwrite("type", &TobiiTypes::eyeImage::type)
        .def_readwrite("camera_id", &TobiiTypes::eyeImage::camera_id)
        .def_property_readonly("image", &imageToNumpy)
        .def(py::pickle(
            [](const TobiiTypes::eyeImage& p) { // __getstate__
                return py::make_tuple(p.isGif, p.device_time_stamp, p.system_time_stamp, p.bits_per_pixel, p.padding_per_pixel, p.width, p.height, p.region_id, p.region_top, p.region_left, p.type, p.camera_id, imageToNumpy(p));
            },
            [](py::tuple t) { // __setstate__
                if (t.size() != 13)
                    throw std::runtime_error("Invalid state!");

                TobiiTypes::eyeImage p;
                p.isGif = t[0].cast<bool>();
                p.device_time_stamp = t[1].cast<int64_t>();
                p.system_time_stamp = t[2].cast<int64_t>();
                p.bits_per_pixel = t[3].cast<int>();
                p.padding_per_pixel = t[4].cast<int>();
                p.width = t[5].cast<int>();
                p.height = t[6].cast<int>();
                p.region_id = t[7].cast<int>();
                p.region_top = t[8].cast<int>();
                p.region_left = t[9].cast<int>();
                p.type = t[10].cast<TobiiResearchEyeImageType>();
                p.camera_id = t[11].cast<int>();
                auto im = t[12].cast<py::array_t<uint8_t>>();
                p.setData(im.data(), im.nbytes());
                return p;
            }
        ))
        .def("__repr__", [](const TobiiTypes::eyeImage& instance_) { return toString(instance_); })
        ;


    // external signal
    py::enum_<TobiiResearchExternalSignalChangeType>(m, "external_signal_change_type")
        .value("value_changed", TobiiResearchExternalSignalChangeType::TOBII_RESEARCH_EXTERNAL_SIGNAL_VALUE_CHANGED)
        .value("initial_value", TobiiResearchExternalSignalChangeType::TOBII_RESEARCH_EXTERNAL_SIGNAL_INITIAL_VALUE)
        .value("connection_restored", TobiiResearchExternalSignalChangeType::TOBII_RESEARCH_EXTERNAL_SIGNAL_CONNECTION_RESTORED)
        .export_values();
    py::class_<TobiiResearchExternalSignalData>(m, "external_signal")
        .def_readwrite("device_time_stamp", &TobiiResearchExternalSignalData::device_time_stamp)
        .def_readwrite("system_time_stamp", &TobiiResearchExternalSignalData::system_time_stamp)
        .def_readwrite("value", &TobiiResearchExternalSignalData::value)
        .def_readwrite("change_type", &TobiiResearchExternalSignalData::change_type)
        .def(py::pickle(
            [](const TobiiResearchExternalSignalData& p) { // __getstate__
                return py::make_tuple(p.device_time_stamp, p.system_time_stamp, p.value, p.change_type);
            },
            [](py::tuple t) { // __setstate__
                if (t.size() != 4)
                    throw std::runtime_error("Invalid state!");

                TobiiResearchExternalSignalData p{ t[0].cast<int64_t>(),t[1].cast<int64_t>(),t[2].cast<uint32_t>(),t[3].cast<TobiiResearchExternalSignalChangeType>() };
                return p;
            }
        ))
        .def("__repr__", [](const TobiiResearchExternalSignalData& instance_) { return toString(instance_); })
        ;


    // time sync
    py::class_<TobiiResearchTimeSynchronizationData>(m, "time_sync")
        .def_readwrite("system_request_time_stamp", &TobiiResearchTimeSynchronizationData::system_request_time_stamp)
        .def_readwrite("device_time_stamp", &TobiiResearchTimeSynchronizationData::device_time_stamp)
        .def_readwrite("system_response_time_stamp", &TobiiResearchTimeSynchronizationData::system_response_time_stamp)
        .def(py::pickle(
            [](const TobiiResearchTimeSynchronizationData& p) { // __getstate__
                return py::make_tuple(p.system_request_time_stamp, p.device_time_stamp, p.system_response_time_stamp);
            },
            [](py::tuple t) { // __setstate__
                if (t.size() != 3)
                    throw std::runtime_error("Invalid state!");

                TobiiResearchTimeSynchronizationData p{ t[0].cast<int64_t>(),t[1].cast<int64_t>(),t[2].cast<int64_t>() };
                return p;
            }
        ))
        .def("__repr__", [](const TobiiResearchTimeSynchronizationData& instance_) { return toString(instance_); })
        ;


    // positioning
    py::class_<TobiiResearchEyeUserPositionGuide>(m, "positioning_eye")
        .def_readwrite("user_position", &TobiiResearchEyeUserPositionGuide::user_position)
        .def_readwrite("validity", &TobiiResearchEyeUserPositionGuide::validity)
        .def(py::pickle(
            [](const TobiiResearchEyeUserPositionGuide& p) { // __getstate__
                return py::make_tuple(p.user_position, p.validity);
            },
            [](py::tuple t) { // __setstate__
                if (t.size() != 2)
                    throw std::runtime_error("Invalid state!");

                TobiiResearchEyeUserPositionGuide p{ t[0].cast<TobiiResearchNormalizedPoint3D>(),t[1].cast<TobiiResearchValidity>() };
                return p;
            }
        ))
        .def("__repr__", [](const TobiiResearchEyeUserPositionGuide& instance_) { return toString(instance_); })
        ;
    py::class_<TobiiResearchUserPositionGuide>(m, "positioning")
        .def_readwrite("left", &TobiiResearchUserPositionGuide::left_eye)
        .def_readwrite("right", &TobiiResearchUserPositionGuide::right_eye)
        .def(py::pickle(
            [](const TobiiResearchUserPositionGuide& p) { // __getstate__
                return py::make_tuple(p.left_eye, p.right_eye);
            },
            [](py::tuple t) { // __setstate__
                if (t.size() != 2)
                    throw std::runtime_error("Invalid state!");

                TobiiResearchUserPositionGuide p{ t[0].cast<TobiiResearchEyeUserPositionGuide>(),t[1].cast<TobiiResearchEyeUserPositionGuide>() };
                return p;
            }
        ))
        .def("__repr__", [](const TobiiResearchUserPositionGuide& instance_) { return toString(instance_); })
        ;


    // notification
    py::enum_<TobiiResearchNotificationType>(m, "external_signal_change_type")
        .value("connection_lost", TobiiResearchNotificationType::TOBII_RESEARCH_NOTIFICATION_CONNECTION_LOST)
        .value("connection_restored", TobiiResearchNotificationType::TOBII_RESEARCH_NOTIFICATION_CONNECTION_RESTORED)
        .value("calibration_mode_entered", TobiiResearchNotificationType::TOBII_RESEARCH_NOTIFICATION_CALIBRATION_MODE_ENTERED)
        .value("calibration_mode_left", TobiiResearchNotificationType::TOBII_RESEARCH_NOTIFICATION_CALIBRATION_MODE_LEFT)
        .value("calibration_changed", TobiiResearchNotificationType::TOBII_RESEARCH_NOTIFICATION_CALIBRATION_CHANGED)
        .value("track_box_changed", TobiiResearchNotificationType::TOBII_RESEARCH_NOTIFICATION_TRACK_BOX_CHANGED)
        .value("display_area_changed", TobiiResearchNotificationType::TOBII_RESEARCH_NOTIFICATION_DISPLAY_AREA_CHANGED)
        .value("gaze_output_frequency_changed", TobiiResearchNotificationType::TOBII_RESEARCH_NOTIFICATION_GAZE_OUTPUT_FREQUENCY_CHANGED)
        .value("eye_tracking_mode_changed", TobiiResearchNotificationType::TOBII_RESEARCH_NOTIFICATION_EYE_TRACKING_MODE_CHANGED)
        .value("device_faults", TobiiResearchNotificationType::TOBII_RESEARCH_NOTIFICATION_DEVICE_FAULTS)
        .value("device_warnings", TobiiResearchNotificationType::TOBII_RESEARCH_NOTIFICATION_DEVICE_WARNINGS)
        .value("notification_unknown", TobiiResearchNotificationType::TOBII_RESEARCH_NOTIFICATION_UNKNOWN)
        .export_values();
    py::class_<TobiiTypes::notification>(m, "notification")
        .def_readwrite("system_time_stamp", &TobiiTypes::notification::system_time_stamp)
        .def_readwrite("notification_type", &TobiiTypes::notification::notification_type)
        .def_readwrite("output_frequency", &TobiiTypes::notification::output_frequency)
        .def_readwrite("display_area", &TobiiTypes::notification::display_area)
        .def_readwrite("errors_or_warnings", &TobiiTypes::notification::errors_or_warnings)
        .def(py::pickle(
            [](const TobiiTypes::notification& p) { // __getstate__
                return py::make_tuple(p.system_time_stamp, p.notification_type, p.output_frequency, p.display_area, p.errors_or_warnings);
            },
            [](py::tuple t) { // __setstate__
                if (t.size() != 2)
                    throw std::runtime_error("Invalid state!");

                TobiiTypes::notification p{ t[0].cast<int64_t>(),t[1].cast<TobiiResearchNotificationType>(),t[2].cast<std::optional<float>>(),t[3].cast<std::optional<TobiiResearchDisplayArea>>(),t[4].cast<std::optional<std::string>>() };
                return p;
            }
        ))
        .def("__repr__", [](const TobiiResearchEyeUserPositionGuide& instance_) { return toString(instance_); })
        ;
    py::class_<TobiiResearchUserPositionGuide>(m, "positioning")
        .def_readwrite("left", &TobiiResearchUserPositionGuide::left_eye)
        .def_readwrite("right", &TobiiResearchUserPositionGuide::right_eye)
        .def(py::pickle(
            [](const TobiiResearchUserPositionGuide& p) { // __getstate__
                return py::make_tuple(p.left_eye, p.right_eye);
            },
            [](py::tuple t) { // __setstate__
                if (t.size() != 2)
                    throw std::runtime_error("Invalid state!");

                TobiiResearchUserPositionGuide p{ t[0].cast<TobiiResearchEyeUserPositionGuide>(),t[1].cast<TobiiResearchEyeUserPositionGuide>() };
                return p;
            }
        ))
        .def("__repr__", [](const TobiiResearchUserPositionGuide& instance_) { return toString(instance_); })
        ;


    // main class
    py::class_<Titta>(m, "wrapper")
        .def(py::init<std::string>(),"address"_a)

        .def("__repr__",
            [](Titta& instance_)
            {
#ifdef NDEBUG
                return string_format("%s (%s, %s) @%.0f Hz at '%s'", instance_.getEyeTrackerInfo().model.c_str(), instance_.getEyeTrackerInfo().serialNumber.c_str(), instance_.getEyeTrackerInfo().deviceName.c_str(), instance_.getEyeTrackerInfo().frequency, instance_.getEyeTrackerInfo().address.c_str());
#else
                return string_format("<TobiiWrapper.wrapper connected to '%s' (%s, %s) @%.0f Hz at '%s'>", instance_.getEyeTrackerInfo().model.c_str(), instance_.getEyeTrackerInfo().serialNumber.c_str(), instance_.getEyeTrackerInfo().deviceName.c_str(), instance_.getEyeTrackerInfo().frequency, instance_.getEyeTrackerInfo().address.c_str());
#endif
            })

        //// global SDK functions
        .def_static("get_SDK_version", &Titta::getSDKVersion)
        .def_static("get_system_timestamp", &Titta::getSystemTimestamp)
        .def_static("find_all_eye_trackers", &Titta::findAllEyeTrackers)
        // logging
        .def_static("start_logging", &Titta::startLogging,
            py::arg_v("initial_buffer_size", std::nullopt, "None"))
        .def_static("get_log", &Titta::getLog,
            py::arg_v("clear_log", std::nullopt, "None"))
        .def_static("stop_logging", &Titta::stopLogging)

        //// eye-tracker specific getters and setters
        .def_property_readonly("info", &Titta::getEyeTrackerInfo)
        .def_property("device_name", [](Titta& instance_) { return instance_.getEyeTrackerInfo("deviceName").deviceName; }, & Titta::setDeviceName)
        .def_property_readonly("serial_number", [](Titta& instance_) { return instance_.getEyeTrackerInfo("serialNumber").serialNumber; })
        .def_property_readonly("model", [](Titta& instance_) { return instance_.getEyeTrackerInfo("model").model; })
        .def_property_readonly("firmware_version", [](Titta& instance_) { return instance_.getEyeTrackerInfo("firmwareVersion").firmwareVersion; })
        .def_property_readonly("runtime_version", [](Titta& instance_) { return instance_.getEyeTrackerInfo("runtimeVersion").runtimeVersion; })
        .def_property_readonly("address", [](Titta& instance_) { return instance_.getEyeTrackerInfo("address").address; })
        .def_property_readonly("capabilities", [](Titta& instance_) { return convertCapabilities(instance_.getEyeTrackerInfo("capabilities").capabilities); })
        .def_property_readonly("supported_frequencies", [](Titta& instance_) { return instance_.getEyeTrackerInfo("supportedFrequencies").supportedFrequencies; })
        .def_property_readonly("supported_modes", [](Titta& instance_) { return instance_.getEyeTrackerInfo("supportedModes").supportedModes; })
        .def_property("frequency", [](Titta& instance_) { return instance_.getEyeTrackerInfo("frequency").frequency; }, &Titta::setFrequency)
        .def_property("tracking_mode", [](Titta& instance_) { return instance_.getEyeTrackerInfo("trackingMode").trackingMode; }, &Titta::setTrackingMode)
        .def_property_readonly("track_box", &Titta::getTrackBox)
        .def_property_readonly("display_area", &Titta::getDisplayArea)
        // modifiers
        .def("apply_licenses", &Titta::applyLicenses,
            "licenses"_a)
        .def("clear_licenses", &Titta::clearLicenses)

        //// calibration
        .def("enter_calibration_mode", &Titta::enterCalibrationMode,
            "do_monocular"_a=false)
        .def("is_in_calibration_mode", &Titta::leaveCalibrationMode,
            py::arg_v("throw_error_if_not", std::nullopt, "None"))
        .def("leave_calibration_mode", &Titta::leaveCalibrationMode,
            py::arg_v("force", std::nullopt, "None"))
        .def("calibration_collect_data", &Titta::calibrationCollectData,
            "coordinates"_a, py::arg_v("eye", std::nullopt, "None"))
        .def("calibration_discard_data", &Titta::calibrationDiscardData,
            "coordinates"_a, py::arg_v("eye", std::nullopt, "None"))
        .def("calibration_compute_and_apply", &Titta::calibrationComputeAndApply)
        .def("calibration_get_data", &Titta::calibrationGetData)
        .def("calibration_apply_data", &Titta::calibrationApplyData,
            "cal_data"_a)
        .def("calibration_get_status", &Titta::calibrationGetStatus)
        .def("calibration_retrieve_result", &Titta::calibrationRetrieveResult,
            "make_string"_a=true)

        //// data streams
        // query if stream is supported
        .def("has_stream", py::overload_cast<std::string>(&Titta::hasStream, py::const_),
            "stream"_a)

        // start stream
        .def("start", py::overload_cast<std::string, std::optional<size_t>, std::optional<bool>>(&Titta::start),
            "stream"_a, py::arg_v("initial_buffer_size", std::nullopt, "None"), py::arg_v("as_GIF", std::nullopt, "None"))

        // request stream state
        .def("is_recording", py::overload_cast<std::string>(&Titta::isRecording, py::const_),
            "stream"_a)

        // consume samples (by default all)
        .def("consume_N",
            [](Titta& instance_, std::string stream_, std::optional<size_t> NSamp_, std::string side_)
            -> std::optional<std::variant<std::vector<Titta::gaze>, std::vector<Titta::eyeImage>, std::vector<Titta::extSignal>, std::vector<Titta::timeSync>, std::vector<Titta::positioning>, std::vector<Titta::notification>>>
            {
                Titta::DataStream dataStream = Titta::stringToDataStream(stream_);

                std::optional<Titta::BufferSide> bufSide;
                if (!side_.empty())
                {
                    bufSide = Titta::stringToBufferSide(side_);
                }

                switch (dataStream)
                {
                case Titta::DataStream::Gaze:
                    return instance_.consumeN<Titta::gaze>(NSamp_, bufSide);
                case Titta::DataStream::EyeImage:
                    return instance_.consumeN<Titta::eyeImage>(NSamp_, bufSide);
                case Titta::DataStream::ExtSignal:
                    return instance_.consumeN<Titta::extSignal>(NSamp_, bufSide);
                case Titta::DataStream::TimeSync:
                    return instance_.consumeN<Titta::timeSync>(NSamp_, bufSide);
                case Titta::DataStream::Positioning:
                    return instance_.consumeN<Titta::positioning>(NSamp_, bufSide);
                case Titta::DataStream::Notification:
                    return instance_.consumeN<Titta::notification>(NSamp_, bufSide);
                }
                return std::nullopt;
            },
            "stream"_a, py::arg_v("N_samples", std::nullopt, "None"), "side"_a="")
        // consume samples within given timestamps (inclusive, by default whole buffer)
        .def("consume_time_range",
            [](Titta& instance_, std::string stream_, std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_)
            -> std::optional<std::variant<std::vector<Titta::gaze>, std::vector<Titta::eyeImage>, std::vector<Titta::extSignal>, std::vector<Titta::timeSync>, std::vector<Titta::notification>>>
            {
                Titta::DataStream dataStream = Titta::stringToDataStream(stream_);

                switch (dataStream)
                {
                case Titta::DataStream::Gaze:
                    return instance_.consumeTimeRange<Titta::gaze>(timeStart_, timeEnd_);
                case Titta::DataStream::EyeImage:
                    return instance_.consumeTimeRange<Titta::eyeImage>(timeStart_, timeEnd_);
                case Titta::DataStream::ExtSignal:
                    return instance_.consumeTimeRange<Titta::extSignal>(timeStart_, timeEnd_);
                case Titta::DataStream::TimeSync:
                    return instance_.consumeTimeRange<Titta::timeSync>(timeStart_, timeEnd_);
                case Titta::DataStream::Positioning:
                    DoExitWithMsg("Titta::cpp::consume_time_range: not supported for positioning stream.");
                case Titta::DataStream::Notification:
                    return instance_.consumeTimeRange<Titta::notification>(timeStart_, timeEnd_);
                }
                return std::nullopt;
            },
            "stream"_a, py::arg_v("time_start", std::nullopt, "None"), py::arg_v("time_end", std::nullopt, "None"))

        // peek samples (by default only last one, can specify how many to peek, and from which side of buffer)
        .def("peek_N",
            [](Titta& instance_, std::string stream_, std::optional<size_t> NSamp_, std::string side_)
            -> std::optional<std::variant<std::vector<Titta::gaze>, std::vector<Titta::eyeImage>, std::vector<Titta::extSignal>, std::vector<Titta::timeSync>, std::vector<Titta::positioning>, std::vector<Titta::notification>>>
            {
                Titta::DataStream dataStream = Titta::stringToDataStream(stream_);

                std::optional<Titta::BufferSide> bufSide;
                if (!side_.empty())
                {
                    bufSide = Titta::stringToBufferSide(side_);
                }

                switch (dataStream)
                {
                case Titta::DataStream::Gaze:
                    return instance_.peekN<Titta::gaze>(NSamp_, bufSide);
                case Titta::DataStream::EyeImage:
                    return instance_.peekN<Titta::eyeImage>(NSamp_, bufSide);
                case Titta::DataStream::ExtSignal:
                    return instance_.peekN<Titta::extSignal>(NSamp_, bufSide);
                case Titta::DataStream::TimeSync:
                    return instance_.peekN<Titta::timeSync>(NSamp_, bufSide);
                case Titta::DataStream::Positioning:
                    return instance_.peekN<Titta::positioning>(NSamp_, bufSide);
                case Titta::DataStream::Notification:
                    return instance_.peekN<Titta::notification>(NSamp_, bufSide);
                }
                return std::nullopt;
            },
            "stream"_a, py::arg_v("N_samples", std::nullopt, "None"), "side"_a = "")
        // peek samples within given timestamps (inclusive, by default whole buffer)
        .def("peek_time_range",
            [](Titta& instance_, std::string stream_, std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_)
            -> std::optional<std::variant<std::vector<Titta::gaze>, std::vector<Titta::eyeImage>, std::vector<Titta::extSignal>, std::vector<Titta::timeSync>, std::vector<Titta::notification>>>
            {
                Titta::DataStream dataStream = Titta::stringToDataStream(stream_);

                switch (dataStream)
                {
                case Titta::DataStream::Gaze:
                    return instance_.peekTimeRange<Titta::gaze>(timeStart_, timeEnd_);
                case Titta::DataStream::EyeImage:
                    return instance_.peekTimeRange<Titta::eyeImage>(timeStart_, timeEnd_);
                case Titta::DataStream::ExtSignal:
                    return instance_.peekTimeRange<Titta::extSignal>(timeStart_, timeEnd_);
                case Titta::DataStream::TimeSync:
                    return instance_.peekTimeRange<Titta::timeSync>(timeStart_, timeEnd_);
                case Titta::DataStream::Positioning:
                    DoExitWithMsg("Titta::cpp::peek_time_range: not supported for positioning stream.");
                case Titta::DataStream::Notification:
                    return instance_.peekTimeRange<Titta::notification>(timeStart_, timeEnd_);
                }
                return std::nullopt;
            },
            "stream"_a, py::arg_v("time_start", std::nullopt, "None"), py::arg_v("time_end", std::nullopt, "None"))

        // clear all buffer contents
        .def("clear", py::overload_cast<std::string>(&Titta::clear),
            "stream"_a)

        // clear contents buffer within given timestamps (inclusive, by default whole buffer)
        .def("clear_time_range", py::overload_cast<std::string, std::optional<int64_t>, std::optional<int64_t>>(&Titta::clearTimeRange),
            "stream"_a, py::arg_v("time_start", std::nullopt, "None"), py::arg_v("time_end", std::nullopt, "None"))

        // stop, optionally deletes the buffer
        .def("stop", py::overload_cast<std::string, std::optional<bool>>(&Titta::stop),
            "stream"_a, py::arg_v("clear_buffer", std::nullopt, "None"))
        ;

// set module version info
#ifdef VERSION_INFO
        m.attr("__version__") = VERSION_INFO;
#else
        m.attr("__version__") = "dev";
#endif
}

// function for handling errors generated by lib
[[ noreturn ]] void DoExitWithMsg(std::string errMsg_)
{
    PyErr_SetString(PyExc_RuntimeError, errMsg_.c_str());
    throw py::error_already_set();
}
void RelayMsg(std::string msg_)
{
    py::print(msg_.c_str());
}