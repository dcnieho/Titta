#include "TobiiMex/TobiiMex.h"
#include "TobiiMex/utils.h"

#include <iostream>
#include <string>
#include <memory>
#include <variant>
#include <optional>
#include <cstdio>
#include <inttypes.h>

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

const char* isValid(TobiiResearchValidity validity_)
{
    return validity_ == TobiiResearchValidity::TOBII_RESEARCH_VALIDITY_VALID ? "valid" : "invalid";
}
const char* imageType(TobiiResearchEyeImageType type_)
{
    return type_ == TobiiResearchEyeImageType::TOBII_RESEARCH_EYE_IMAGE_TYPE_FULL ? "full" : (TobiiResearchEyeImageType::TOBII_RESEARCH_EYE_IMAGE_TYPE_FULL ? "cropped" : "unknown");
}
const char* external_signal_change_type(TobiiResearchExternalSignalChangeType type_)
{
    return type_ == TobiiResearchExternalSignalChangeType::TOBII_RESEARCH_EXTERNAL_SIGNAL_VALUE_CHANGED ? "value_changed" : (TobiiResearchExternalSignalChangeType::TOBII_RESEARCH_EXTERNAL_SIGNAL_INITIAL_VALUE ? "initial_value" : "connection_restored");
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
    return string_format("(validity: %s)\n%son_display_area: %s\n%sin_user_coordinates: %s", isValid(instance_.validity), spacing.c_str(), toString(instance_.position_on_display_area, nextLvl).c_str(), spacing.c_str(), toString(instance_.position_in_user_coordinates, nextLvl).c_str());
#else
    return string_format("<TobiiWrapper.gaze_point (validity: %s) containing:\n%son_display_area: %s\n%sin_user_coordinates: %s>", isValid(instance_.validity), spacing.c_str(), toString(instance_.position_on_display_area, nextLvl).c_str(), spacing.c_str(), toString(instance_.position_in_user_coordinates, nextLvl).c_str());
#endif
}
template <> std::string toString<>(const TobiiResearchPupilData& instance_, std::string spacing)
{
    auto nextLvl = spacing + "  ";
#ifdef NDEBUG
    return string_format("(validity: %s)\n%sdiameter: %.3f mm", isValid(instance_.validity), nextLvl.c_str(), instance_.diameter);
#else
    return string_format("<TobiiWrapper.pupil_data (validity: %s) containing:\n%sdiameter: %.3f mm>", isValid(instance_.validity), nextLvl.c_str(), instance_.diameter);
#endif
}
template <> std::string toString<>(const TobiiResearchGazeOrigin& instance_, std::string spacing)
{
    auto nextLvl = spacing + "  ";
#ifdef NDEBUG
    return string_format("(validity: %s)\n%sin_user_coordinates: %s\n%sin_track_box_coordinates: %s", isValid(instance_.validity), spacing.c_str(), toString(instance_.position_in_user_coordinates, nextLvl).c_str(), spacing.c_str(), toString(instance_.position_in_track_box_coordinates, nextLvl).c_str());
#else
    return string_format("<TobiiWrapper.gaze_origin (validity: %s) containing:\n%sin_user_coordinates: %s\n%sin_track_box_coordinates: %s>", isValid(instance_.validity), spacing.c_str(), toString(instance_.position_in_user_coordinates, nextLvl).c_str(), spacing.c_str(), toString(instance_.position_in_track_box_coordinates, nextLvl).c_str());
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
    return string_format("%s image taken at system_time: %" PRId64 " with camera %d, %dbit, %dx%d", imageType(instance_.type), instance_.system_time_stamp, instance_.camera_id, instance_.bits_per_pixel, instance_.width, instance_.height);
}

template <> std::string toString<>(const TobiiResearchExternalSignalData& instance_, std::string spacing)
{
    return string_format("external signal arrived at system_time: %" PRId64 ", type: %s, value: %d", instance_.system_time_stamp, external_signal_change_type(instance_.change_type), instance_.value);
}

template <> std::string toString<>(const TobiiResearchTimeSynchronizationData& instance_, std::string spacing)
{
    return string_format("time sync system_request_time_stamp: %" PRId64 ", device_time_stamp: %" PRId64 ", system_response_time_stamp: %" PRId64 "", instance_.system_request_time_stamp, instance_.device_time_stamp, instance_.system_response_time_stamp);
}

template <> std::string toString<>(const TobiiResearchEyeUserPositionGuide& instance_, std::string spacing)
{
    auto nextLvl = spacing + "  ";
#ifdef NDEBUG
    return string_format("(validity: %s)\n%suser_position: %s", isValid(instance_.validity), spacing.c_str(), toString(instance_.user_position, nextLvl).c_str());
#else
    return string_format("<TobiiWrapper.positioning_eye (validity: %s) containing:\n%suser_position: %s>", isValid(instance_.validity), spacing.c_str(), toString(instance_.user_position, nextLvl).c_str());
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


// start module scope
#ifdef NDEBUG
PYBIND11_MODULE(TobiiWrapper_python, m)
#else
PYBIND11_MODULE(TobiiWrapper_python_d, m)
#endif
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
        .def_readwrite("capabilities", &TobiiTypes::eyeTracker::capabilities)
        .def_readwrite("supported_frequencies", &TobiiTypes::eyeTracker::supportedFrequencies)
        .def_readwrite("supported_modes", &TobiiTypes::eyeTracker::supportedModes)
        .def(py::pickle(
            [](const TobiiTypes::eyeTracker& p) { // __getstate__
                return py::make_tuple(p.deviceName, p.serialNumber, p.model, p.firmwareVersion, p.runtimeVersion, p.address, p.capabilities, p.supportedFrequencies, p.supportedModes);
            },
            [](py::tuple t) { // __setstate__
                if (t.size() != 9)
                    throw std::runtime_error("Invalid state!");

                TobiiTypes::eyeTracker p{ t[0].cast<std::string>(),t[1].cast<std::string>(),t[2].cast<std::string>(),t[3].cast<std::string>(),t[4].cast<std::string>(),t[5].cast<std::string>(),t[6].cast<TobiiResearchCapabilities>(),t[7].cast<std::vector<float>>(),t[8].cast<std::vector<std::string>>() };
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
        .def_readwrite("type", &TobiiTypes::eyeImage::type)
        .def_readwrite("camera_id", &TobiiTypes::eyeImage::camera_id)
        .def_property_readonly("image", &imageToNumpy)
        .def(py::pickle(
            [](const TobiiTypes::eyeImage& p) { // __getstate__
                return py::make_tuple(p.isGif, p.device_time_stamp, p.system_time_stamp, p.bits_per_pixel, p.padding_per_pixel, p.width, p.height, p.type, p.camera_id, imageToNumpy(p));
            },
            [](py::tuple t) { // __setstate__
                if (t.size() != 10)
                    throw std::runtime_error("Invalid state!");

                TobiiTypes::eyeImage p;
                p.isGif = t[0].cast<bool>();
                p.device_time_stamp = t[1].cast<int64_t>();
                p.system_time_stamp = t[2].cast<int64_t>();
                p.bits_per_pixel = t[3].cast<int>();
                p.padding_per_pixel = t[4].cast<int>();
                p.width = t[5].cast<int>();
                p.height = t[6].cast<int>();
                p.type = t[7].cast<TobiiResearchEyeImageType>();
                p.camera_id = t[8].cast<int>();
                auto im = t[9].cast<py::array_t<uint8_t>>();
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


    // main class
    py::class_<TobiiMex>(m, "wrapper")
        .def(py::init<std::string>(),"address"_a)

        .def("__repr__",
            [](TobiiMex& instance_)
            {
#ifdef NDEBUG
                return string_format("%s (%s, %s) @%.0f Hz at '%s'", instance_.getConnectedEyeTracker().model.c_str(), instance_.getConnectedEyeTracker().serialNumber.c_str(), instance_.getConnectedEyeTracker().deviceName.c_str(), instance_.getCurrentFrequency(), instance_.getConnectedEyeTracker().address.c_str());
#else
                return string_format("<TobiiWrapper.wrapper connected to '%s' (%s, %s) @%.0f Hz at '%s'>", instance_.getConnectedEyeTracker().model.c_str(), instance_.getConnectedEyeTracker().serialNumber.c_str(), instance_.getConnectedEyeTracker().deviceName.c_str(), instance_.getCurrentFrequency(), instance_.getConnectedEyeTracker().address.c_str());
#endif
            })

        //// global SDK functions
        .def_static("getSDKVersion", &TobiiMex::getSDKVersion)
        .def_static("getSystemTimestamp", &TobiiMex::getSystemTimestamp)
        .def_static("findAllEyeTrackers", &TobiiMex::findAllEyeTrackers)
        // logging
        .def_static("startLogging", &TobiiMex::startLogging,
            py::arg_v("initialBufferSize", std::nullopt, "None"))
        .def_static("getLog", &TobiiMex::getLog,
            py::arg_v("clearLog", std::nullopt, "None"))
        .def_static("stopLogging", &TobiiMex::stopLogging)

        //// eye-tracker specific getters and setters
        // getters
        .def_property_readonly("connected_eye_tracker", &TobiiMex::getConnectedEyeTracker)
        .def_property("gaze_frequency", &TobiiMex::getCurrentFrequency, &TobiiMex::setGazeFrequency)
        .def_property("tracking_mode", &TobiiMex::getCurrentTrackingMode, &TobiiMex::setTrackingMode)
        .def_property_readonly("track_box", &TobiiMex::getTrackBox)
        .def_property_readonly("display_area", &TobiiMex::getDisplayArea)
        // setters (though we can easily provide the getter for this property too, so lets do that to keep our user's life simple
        .def_property("device_name", [](TobiiMex& instance_) { return instance_.getConnectedEyeTracker().deviceName; }, &TobiiMex::setDeviceName)
        // modifiers

        //// calibration

        //// data streams
        // query if stream is supported
        // start stream
        .def("start", py::overload_cast<std::string, std::optional<size_t>, std::optional<bool>>(&TobiiMex::start),
            "stream"_a, py::arg_v("initialBufferSize", std::nullopt, "None"), py::arg_v("asGif", std::nullopt, "None"))

        // request stream state

        // consume samples (by default all)
        .def("consumeN",
            [](TobiiMex& instance_, std::string stream_, std::optional<size_t> NSamp_, std::string side_)
            -> std::optional<std::variant<std::vector<TobiiMex::gaze>, std::vector<TobiiMex::eyeImage>, std::vector<TobiiMex::extSignal>, std::vector<TobiiMex::timeSync>, std::vector<TobiiMex::positioning>>>
            {
                TobiiMex::DataStream dataStream = TobiiMex::stringToDataStream(stream_);

                std::optional<TobiiMex::BufferSide> bufSide;
                if (!side_.empty())
                {
                    bufSide = TobiiMex::stringToBufferSide(side_);
                }

                switch (dataStream)
                {
                case TobiiMex::DataStream::Gaze:
                    return instance_.consumeN<TobiiMex::gaze>(NSamp_, bufSide);
                case TobiiMex::DataStream::EyeImage:
                    return instance_.consumeN<TobiiMex::eyeImage>(NSamp_, bufSide);
                case TobiiMex::DataStream::ExtSignal:
                    return instance_.consumeN<TobiiMex::extSignal>(NSamp_, bufSide);
                case TobiiMex::DataStream::TimeSync:
                    return instance_.consumeN<TobiiMex::timeSync>(NSamp_, bufSide);
                case TobiiMex::DataStream::Positioning:
                    return instance_.consumeN<TobiiMex::positioning>(NSamp_, bufSide);
                }
                return std::nullopt;
            },
            "stream"_a, py::arg_v("NSamp", std::nullopt, "None"), "side"_a="")
        // consume samples within given timestamps (inclusive, by default whole buffer)

        // peek samples (by default only last one, can specify how many to peek, and from which side of buffer)
        .def("peekN",
            [](TobiiMex& instance_, std::string stream_, std::optional<size_t> NSamp_, std::string side_)
            -> std::optional<std::variant<std::vector<TobiiMex::gaze>, std::vector<TobiiMex::eyeImage>, std::vector<TobiiMex::extSignal>, std::vector<TobiiMex::timeSync>, std::vector<TobiiMex::positioning>>>
            {
                TobiiMex::DataStream dataStream = TobiiMex::stringToDataStream(stream_);

                std::optional<TobiiMex::BufferSide> bufSide;
                if (!side_.empty())
                {
                    bufSide = TobiiMex::stringToBufferSide(side_);
                }

                switch (dataStream)
                {
                case TobiiMex::DataStream::Gaze:
                    return instance_.peekN<TobiiMex::gaze>(NSamp_, bufSide);
                case TobiiMex::DataStream::EyeImage:
                    return instance_.peekN<TobiiMex::eyeImage>(NSamp_, bufSide);
                case TobiiMex::DataStream::ExtSignal:
                    return instance_.peekN<TobiiMex::extSignal>(NSamp_, bufSide);
                case TobiiMex::DataStream::TimeSync:
                    return instance_.peekN<TobiiMex::timeSync>(NSamp_, bufSide);
                case TobiiMex::DataStream::Positioning:
                    return instance_.peekN<TobiiMex::positioning>(NSamp_, bufSide);
                }
                return std::nullopt;
            },
            "stream"_a, py::arg_v("NSamp", std::nullopt, "None"), "side"_a = "")
        // peek samples within given timestamps (inclusive, by default whole buffer)

        // clear all buffer contents
        // clear contents buffer within given timestamps (inclusive, by default whole buffer)

        // stop, optionally deletes the buffer
        .def("stop", py::overload_cast<std::string, std::optional<bool>>(&TobiiMex::stop),
            "stream"_a, py::arg_v("emptyBuffer", std::nullopt, "None"))
        ;
}

// function for handling errors generated by lib
void DoExitWithMsg(std::string errMsg_)
{
    PyErr_SetString(PyExc_RuntimeError, errMsg_.c_str());
    throw py::error_already_set();
}
void RelayMsg(std::string msg_)
{
    py::print(msg_.c_str());
}