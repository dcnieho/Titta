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

#include "cpp_mex_helpers/get_field_nested.h"
#include "cpp_mex_helpers/mem_var_trait.h"
#include "tobii_elem_count.h"


namespace
{
// default output is storage type corresponding to the type of the member variable accessed through this function, but it can be overridden through type tag dispatch (see nested_field::getWrapper implementation)
template<bool UseArray, typename V, typename... Fs>
void FieldToNpArray(py::dict& out_, const std::vector<V>& data_, const std::string& name_, Fs... fields_)
{
    using U = decltype(nested_field::getWrapper(std::declval<V>(), fields_...));
    auto nElem = static_cast<py::ssize_t>(data_.size());

    if constexpr (UseArray)
    {
        py::array_t<U> a;
        a.resize({ nElem });

        if (data_.size())
        {
            auto storage = a.mutable_data();
            for (auto&& item : data_)
                (*storage++) = nested_field::getWrapper(item, fields_...);
        }

        out_[name_.c_str()] = a;
    }
    else
    {
        py::list l;

        if (data_.size())
            for (auto&& item : data_)
                l.append(nested_field::getWrapper(item, fields_...));

        out_[name_.c_str()] = l;
    }
}

template<typename V, typename... Fs>
void TobiiFieldToNpArray(py::dict& out_, const std::vector<V>& data_, const std::string& name_, Fs... fields)
{
    // get type member variable accessed through the last pointer-to-member-variable in the parameter pack (this is not necessarily the last type in the parameter pack as that can also be the type tag if the user explicitly requested a return type)
    using memVar = std::conditional_t<std::is_member_object_pointer_v<last<0, V, Fs...>>, last<0, V, Fs...>, last<1, V, Fs...>>;
    using retT = memVarType_t<memVar>;
    // based on type, get number of rows for output
    constexpr auto numElements = getNumElements<retT>();

    // this is one of the 2D/3D point types
    // determine what return type we get
    // NB: appending extra field to access leads to wrong order if type tag was provided by user. nested_field::getWrapper detects this and corrects for it
    using U = decltype(nested_field::getWrapper(std::declval<V>(), std::forward<Fs>(fields)..., &retT::x));

    FieldToNpArray<true>(out_, data_, name_ + "_x", std::forward<Fs>(fields)..., &retT::x);
    FieldToNpArray<true>(out_, data_, name_ + "_y", std::forward<Fs>(fields)..., &retT::y);
    if constexpr (numElements == 3)
        FieldToNpArray<true>(out_, data_, name_ + "_z", std::forward<Fs>(fields)..., &retT::z);
}

void FieldToNpArray(py::dict& out_, const std::vector<Titta::gaze>& data_, const std::string& name_, TobiiTypes::eyeData Titta::gaze::* field_)
{
    // 1. gaze_point
    auto localName = name_ + "_gaze_point_";
    // 1.1 gaze_point_on_display_area
    TobiiFieldToNpArray (out_, data_, localName+"on_display_area"    , field_, &TobiiTypes::eyeData::gaze_point, &TobiiTypes::gazePoint::position_on_display_area);
    // 1.2 gaze_point_in_user_coordinates
    TobiiFieldToNpArray (out_, data_, localName+"in_user_coordinates", field_, &TobiiTypes::eyeData::gaze_point, &TobiiTypes::gazePoint::position_in_user_coordinates);
    // 1.3 gaze_point_valid
    FieldToNpArray<true>(out_, data_, localName+"valid"              , field_, &TobiiTypes::eyeData::gaze_point, &TobiiTypes::gazePoint::validity, TOBII_RESEARCH_VALIDITY_VALID);
    // 1.4 gaze_point_available
    FieldToNpArray<true>(out_, data_, localName+"available"          , field_, &TobiiTypes::eyeData::gaze_point, &TobiiTypes::gazePoint::available);

    // 2. pupil
    localName = name_ + "_pupil_";
    // 2.1 pupil_diameter
    FieldToNpArray<true>(out_, data_, localName + "diameter" , field_, &TobiiTypes::eyeData::pupil, &TobiiTypes::pupilData::diameter);
    // 2.2 pupil_valid
    FieldToNpArray<true>(out_, data_, localName + "valid"    , field_, &TobiiTypes::eyeData::pupil, &TobiiTypes::pupilData::validity, TOBII_RESEARCH_VALIDITY_VALID);
    // 2.3 pupil_available
    FieldToNpArray<true>(out_, data_, localName + "available", field_, &TobiiTypes::eyeData::pupil, &TobiiTypes::pupilData::available);

    // 3. gazeOrigin
    localName = name_ + "_gaze_origin_";
    // 3.1 gaze_origin_in_user_coordinates
    TobiiFieldToNpArray (out_, data_, localName + "in_user_coordinates"     , field_, &TobiiTypes::eyeData::gaze_origin, &TobiiTypes::gazeOrigin::position_in_user_coordinates);
    // 3.2 gaze_origin_in_track_box_coordinates
    TobiiFieldToNpArray (out_, data_, localName + "in_track_box_coordinates", field_, &TobiiTypes::eyeData::gaze_origin, &TobiiTypes::gazeOrigin::position_in_track_box_coordinates);
    // 3.3 gaze_origin_valid
    FieldToNpArray<true>(out_, data_, localName + "valid"                   , field_, &TobiiTypes::eyeData::gaze_origin, &TobiiTypes::gazeOrigin::validity, TOBII_RESEARCH_VALIDITY_VALID);
    // 3.4 gaze_origin_available
    FieldToNpArray<true>(out_, data_, localName + "available"               , field_, &TobiiTypes::eyeData::gaze_origin, &TobiiTypes::gazeOrigin::available);

    // 4. eyeOpenness
    localName = name_ + "_eye_openness_";
    // 4.1 eye_openness_diameter
    FieldToNpArray<true>(out_, data_, localName + "diameter"  , field_, &TobiiTypes::eyeData::eye_openness, &TobiiTypes::eyeOpenness::diameter);
    // 4.2 eye_openness_valid
    FieldToNpArray<true>(out_, data_, localName + "valid"     , field_, &TobiiTypes::eyeData::eye_openness, &TobiiTypes::eyeOpenness::validity, TOBII_RESEARCH_VALIDITY_VALID);
    // 4.3 eye_openness_available
    FieldToNpArray<true>(out_, data_, localName + "available" , field_, &TobiiTypes::eyeData::eye_openness, &TobiiTypes::eyeOpenness::available);
}


// eye images
template <typename S, typename T, typename R>
bool allEquals(const std::vector<S>& data_, T S::* field_, const R& ref_)
{
    for (auto& frame : data_)
        if (frame.*field_ != ref_)
            return false;
    return true;
}

py::array_t<uint8_t> imageToNumpy(const TobiiTypes::eyeImage& e_)
{
    py::array_t<uint8_t> a;
    a.resize({ e_.height, e_.width });
    std::memcpy(a.mutable_data(), e_.data(), e_.data_size);
    return a;
}
void outputEyeImages(py::dict& out_, const std::vector<Titta::eyeImage>& data_, const std::string& name_)
{
    if (data_.empty())
    {
        out_[name_.c_str()] = py::list();
        return;
    }

    py::list l;
    for (const auto& frame : data_)
    {
        if (!frame.is_gif)
            l.append(imageToNumpy(frame));
        else
            l.append(py::array_t<uint8_t>(static_cast<py::ssize_t>(frame.data_size), static_cast<uint8_t*>(frame.data())));
    }
    out_[name_.c_str()] = l;
}



py::dict StructVectorToDict(std::vector<Titta::gaze>&& data_)
{
    py::dict out;

    // 1. device timestamps
    FieldToNpArray<true>(out, data_, "device_time_stamp", &Titta::gaze::device_time_stamp);
    // 2. system timestamps
    FieldToNpArray<true>(out, data_, "system_time_stamp", &Titta::gaze::system_time_stamp);
    // 3. left  eye data
    FieldToNpArray(out, data_, "left" , &Titta::gaze::left_eye);
    // 4. right eye data
    FieldToNpArray(out, data_, "right", &Titta::gaze::right_eye);

    return out;
}

py::dict StructVectorToDict(std::vector<Titta::eyeImage>&& data_)
{
    py::dict out;

    // check if all gif, then don't output unneeded fields
    const bool allGif = allEquals(data_, &Titta::eyeImage::is_gif, true);

    FieldToNpArray<true>(out, data_, "device_time_stamp", &Titta::eyeImage::device_time_stamp);
    FieldToNpArray<true>(out, data_, "system_time_stamp", &Titta::eyeImage::system_time_stamp);
    FieldToNpArray<true>(out, data_, "region_id"        , &Titta::eyeImage::region_id);
    FieldToNpArray<true>(out, data_, "region_top"       , &Titta::eyeImage::region_top);
    FieldToNpArray<true>(out, data_, "region_left"      , &Titta::eyeImage::region_left);
    if (!allGif)
    {
        FieldToNpArray<true>(out, data_, "bits_per_pixel"   , &Titta::eyeImage::bits_per_pixel);
        FieldToNpArray<true>(out, data_, "padding_per_pixel", &Titta::eyeImage::padding_per_pixel);
    }
    FieldToNpArray<false>(out, data_, "type"     , &Titta::eyeImage::type);
    FieldToNpArray<true> (out, data_, "camera_id", &Titta::eyeImage::camera_id);
    FieldToNpArray<true> (out, data_, "is_gif"   , &Titta::eyeImage::is_gif);
    outputEyeImages(out, data_, "image");

    return out;
}

py::dict StructVectorToDict(std::vector<Titta::extSignal>&& data_)
{
    py::dict out;

    FieldToNpArray<true>(out, data_, "device_time_stamp", &Titta::extSignal::device_time_stamp);
    FieldToNpArray<true>(out, data_, "system_time_stamp", &Titta::extSignal::system_time_stamp);
    FieldToNpArray<true>(out, data_, "value"            , &Titta::extSignal::value);
    FieldToNpArray<false>(out, data_, "change_type"     , &Titta::extSignal::change_type);

    return out;
}

py::dict StructVectorToDict(std::vector<Titta::timeSync>&& data_)
{
    py::dict out;

    FieldToNpArray<true>(out, data_, "system_request_time_stamp" , &Titta::timeSync::system_request_time_stamp);
    FieldToNpArray<true>(out, data_, "device_time_stamp"         , &Titta::timeSync::device_time_stamp);
    FieldToNpArray<true>(out, data_, "system_response_time_stamp", &Titta::timeSync::system_response_time_stamp);

    return out;
}

py::dict StructVectorToDict(std::vector<Titta::positioning>&& data_)
{
    py::dict out;

    TobiiFieldToNpArray(out, data_, "left_user_position"        , &Titta::positioning::left_eye , &TobiiResearchEyeUserPositionGuide::user_position);
    FieldToNpArray<true>(out, data_, "left_user_position_valid" , &Titta::positioning::left_eye , &TobiiResearchEyeUserPositionGuide::validity, TOBII_RESEARCH_VALIDITY_VALID);
    TobiiFieldToNpArray(out, data_, "right_user_position"       , &Titta::positioning::right_eye, &TobiiResearchEyeUserPositionGuide::user_position);
    FieldToNpArray<true>(out, data_, "right_user_position_valid", &Titta::positioning::right_eye, &TobiiResearchEyeUserPositionGuide::validity, TOBII_RESEARCH_VALIDITY_VALID);

    return out;
}

py::dict StructVectorToDict(std::vector<Titta::notification>&& data_)
{
    py::dict out;

    FieldToNpArray<true> (out, data_, "system_time_stamp" , &Titta::notification::system_time_stamp);
    FieldToNpArray<false>(out, data_, "notification_type" , &Titta::notification::notification_type);
    FieldToNpArray<false>(out, data_, "output_frequency"  , &Titta::notification::output_frequency);
    FieldToNpArray<false>(out, data_, "display_area"      , &Titta::notification::display_area);
    FieldToNpArray<false>(out, data_, "errors_or_warnings", &Titta::notification::errors_or_warnings);

    return out;
}

py::dict StructToDict(const Titta::logMessage& data_)
{
    py::dict d;

    d["system_time_stamp"]  = data_.system_time_stamp;
    d["source"]             = data_.source;
    d["level"]              = data_.level;
    d["message"]            = data_.message;

    return d;
}

py::dict StructToDict(const Titta::streamError& data_)
{
    py::dict d;

    d["machine_serial"]     = data_.machine_serial;
    d["system_time_stamp"]  = data_.system_time_stamp;
    d["error"]              = data_.error;
    d["source"]             = data_.source;
    d["message"]            = data_.message;

    return d;
}

py::list StructVectorToList(std::vector<std::variant<TobiiTypes::logMessage, TobiiTypes::streamErrorMessage>>&& data_)
{
    py::list out;

    for (auto&& item : data_)
        out.append(std::visit([](auto& a_) {return StructToDict(a_); }, item));

    return out;
}

py::list StructToList(const TobiiResearchPoint3D& data_)
{
    return py::cast(std::array<float, 3>{data_.x, data_.y, data_.z});
}

void FieldToNpArray(py::dict& out_, const std::vector<TobiiResearchCalibrationSample>& data_, const std::string& name_, TobiiResearchCalibrationEyeData TobiiResearchCalibrationSample::* field_)
{
    TobiiFieldToNpArray  (out_, data_, name_ + "_position_on_display_area", field_, &TobiiResearchCalibrationEyeData::position_on_display_area);
    FieldToNpArray<false>(out_, data_, name_ + "_validity"                , field_, &TobiiResearchCalibrationEyeData::validity);
}

py::list StructVectorToList(const std::vector<TobiiTypes::CalibrationPoint>& data_)
{
    py::list out;

    for (auto&& i : data_)
    {
        py::dict d;

        d["position_on_display_area_x"] = i.position_on_display_area.x;
        d["position_on_display_area_y"] = i.position_on_display_area.y;

        FieldToNpArray(d, i.calibration_samples, "samples_left",  &TobiiResearchCalibrationSample::left_eye);
        FieldToNpArray(d, i.calibration_samples, "samples_right", &TobiiResearchCalibrationSample::right_eye);

        out.append(d);
    }

    return out;
}

py::dict StructToDict(const TobiiTypes::CalibrationResult& data_)
{
    py::dict d;

    d["points"] = StructVectorToList(data_.calibration_points);
    d["status"] = data_.status;

    return d;
}

py::dict StructToDict(const TobiiTypes::CalibrationWorkItem& data_)
{
    py::dict d;

    d["action"] = data_.action;
    if (data_.coordinates.has_value())
        d["coordinates"] = *data_.coordinates;
    if (data_.eye.has_value())
        d["eye"] = *data_.eye;
    if (data_.calibrationData.has_value())
        d["calibration_data"] = *data_.calibrationData;

    return d;
}

py::dict StructToDict(const TobiiTypes::CalibrationWorkResult& data_)
{
    py::dict d;

    d["work_item"] = StructToDict(data_.workItem);
    d["status"] = static_cast<int>(data_.status);
    d["status_string"] = data_.statusString;
    if (data_.calibrationResult.has_value())
        d["calibration_result"] = StructToDict(*data_.calibrationResult);
    if (data_.calibrationData.has_value())
        d["calibration_data"] = *data_.calibrationData;

    return d;
}

py::list CapabilitiesToList(TobiiResearchCapabilities data_)
{
    py::list l;
    if (data_ & TOBII_RESEARCH_CAPABILITIES_CAN_SET_DISPLAY_AREA)
        l.append(TOBII_RESEARCH_CAPABILITIES_CAN_SET_DISPLAY_AREA);
    if (data_ & TOBII_RESEARCH_CAPABILITIES_HAS_EXTERNAL_SIGNAL)
        l.append(TOBII_RESEARCH_CAPABILITIES_HAS_EXTERNAL_SIGNAL);
    if (data_ & TOBII_RESEARCH_CAPABILITIES_HAS_EYE_IMAGES)
        l.append(TOBII_RESEARCH_CAPABILITIES_HAS_EYE_IMAGES);
    if (data_ & TOBII_RESEARCH_CAPABILITIES_HAS_GAZE_DATA)
        l.append(TOBII_RESEARCH_CAPABILITIES_HAS_GAZE_DATA);
    if (data_ & TOBII_RESEARCH_CAPABILITIES_HAS_HMD_GAZE_DATA)
        l.append(TOBII_RESEARCH_CAPABILITIES_HAS_HMD_GAZE_DATA);
    if (data_ & TOBII_RESEARCH_CAPABILITIES_CAN_DO_SCREEN_BASED_CALIBRATION)
        l.append(TOBII_RESEARCH_CAPABILITIES_CAN_DO_SCREEN_BASED_CALIBRATION);
    if (data_ & TOBII_RESEARCH_CAPABILITIES_CAN_DO_HMD_BASED_CALIBRATION)
        l.append(TOBII_RESEARCH_CAPABILITIES_CAN_DO_HMD_BASED_CALIBRATION);
    if (data_ & TOBII_RESEARCH_CAPABILITIES_HAS_HMD_LENS_CONFIG)
        l.append(TOBII_RESEARCH_CAPABILITIES_HAS_HMD_LENS_CONFIG);
    if (data_ & TOBII_RESEARCH_CAPABILITIES_CAN_DO_MONOCULAR_CALIBRATION)
        l.append(TOBII_RESEARCH_CAPABILITIES_CAN_DO_MONOCULAR_CALIBRATION);
    if (data_ & TOBII_RESEARCH_CAPABILITIES_HAS_EYE_OPENNESS_DATA)
        l.append(TOBII_RESEARCH_CAPABILITIES_HAS_EYE_OPENNESS_DATA);
    return l;
}

py::dict StructToDict(const TobiiTypes::eyeTracker& data_)
{
    py::dict d;
    d["device_name"] = data_.deviceName;
    d["serial_number"] = data_.serialNumber;
    d["model"] = data_.model;
    d["firmware_version"] = data_.firmwareVersion;
    d["runtime_version"] = data_.runtimeVersion;
    d["address"] = data_.address;
    d["frequency"] = data_.frequency;
    d["tracking_mode"] = data_.trackingMode;
    d["capabilities"] = CapabilitiesToList(data_.capabilities);
    d["supported_frequencies"] = data_.supportedFrequencies;
    d["supported_modes"] = data_.supportedModes;
    return d;
}
py::list StructVectorToList(const std::vector<TobiiTypes::eyeTracker>& data_)
{
    py::list out;

    for (auto&& i : data_)
        out.append(StructToDict(i));

    return out;
}

py::dict StructToDict(const TobiiResearchTrackBox& data_)
{
    py::dict d;

    d["back_lower_left"] = StructToList(data_.back_lower_left);
    d["back_lower_right"] = StructToList(data_.back_lower_right);
    d["back_upper_left"] = StructToList(data_.back_upper_left);
    d["back_upper_right"] = StructToList(data_.back_upper_right);
    d["front_lower_left"] = StructToList(data_.front_lower_left);
    d["front_lower_right"] = StructToList(data_.front_lower_right);
    d["front_upper_left"] = StructToList(data_.front_upper_left);
    d["front_upper_right"] = StructToList(data_.front_upper_right);

    return d;
}

py::dict StructToDict(const TobiiResearchDisplayArea& data_)
{
    py::dict d;
    d["bottom_left"] = StructToList(data_.bottom_left);
    d["bottom_right"] = StructToList(data_.bottom_right);
    d["top_left"] = StructToList(data_.top_left);
    d["top_right"] = StructToList(data_.top_right);
    d["width"] = data_.width;
    d["height"] = data_.height;

    return d;
}
}


// start module scope
#ifdef NDEBUG
#   define MODULE_NAME TittaPy
#else
#   define MODULE_NAME TittaPy_d
#endif
PYBIND11_MODULE(MODULE_NAME, m)
{
    // capabilities
    py::enum_<TobiiResearchCapabilities>(m, "capability")
        .value("can_set_display_area", TOBII_RESEARCH_CAPABILITIES_CAN_SET_DISPLAY_AREA)
        .value("has_external_signal", TOBII_RESEARCH_CAPABILITIES_HAS_EXTERNAL_SIGNAL)
        .value("has_eye_images", TOBII_RESEARCH_CAPABILITIES_HAS_EYE_IMAGES)
        .value("has_gaze_data", TOBII_RESEARCH_CAPABILITIES_HAS_GAZE_DATA)
        .value("has_HMD_gaze_data", TOBII_RESEARCH_CAPABILITIES_HAS_HMD_GAZE_DATA)
        .value("can_do_screen_based_calibration", TOBII_RESEARCH_CAPABILITIES_CAN_DO_SCREEN_BASED_CALIBRATION)
        .value("can_do_HMD_based_calibration", TOBII_RESEARCH_CAPABILITIES_CAN_DO_HMD_BASED_CALIBRATION)
        .value("has_HMD_lens_config", TOBII_RESEARCH_CAPABILITIES_HAS_HMD_LENS_CONFIG)
        .value("can_do_monocular_calibration", TOBII_RESEARCH_CAPABILITIES_CAN_DO_MONOCULAR_CALIBRATION)
        .value("has_eye_openness_data", TOBII_RESEARCH_CAPABILITIES_HAS_EYE_OPENNESS_DATA)
        ;
    // logging
    py::enum_<TobiiResearchLogSource>(m, "log_source")
        .value("stream_engine", TobiiResearchLogSource::TOBII_RESEARCH_LOG_SOURCE_STREAM_ENGINE)
        .value("SDK", TobiiResearchLogSource::TOBII_RESEARCH_LOG_SOURCE_SDK)
        .value("firmware_upgrade", TobiiResearchLogSource::TOBII_RESEARCH_LOG_SOURCE_FIRMWARE_UPGRADE)
        ;
    py::enum_<TobiiResearchLogLevel>(m, "log_level")
        .value("error", TobiiResearchLogLevel::TOBII_RESEARCH_LOG_LEVEL_ERROR)
        .value("warning", TobiiResearchLogLevel::TOBII_RESEARCH_LOG_LEVEL_WARNING)
        .value("information", TobiiResearchLogLevel::TOBII_RESEARCH_LOG_LEVEL_INFORMATION)
        .value("debug", TobiiResearchLogLevel::TOBII_RESEARCH_LOG_LEVEL_DEBUG)
        .value("trace", TobiiResearchLogLevel::TOBII_RESEARCH_LOG_LEVEL_TRACE)
        ;
    py::enum_<TobiiResearchStreamError>(m, "stream_error")
        .value("connection_lost", TobiiResearchStreamError::TOBII_RESEARCH_STREAM_ERROR_CONNECTION_LOST)
        .value("insufficient_license", TobiiResearchStreamError::TOBII_RESEARCH_STREAM_ERROR_INSUFFICIENT_LICENSE)
        .value("not_supported", TobiiResearchStreamError::TOBII_RESEARCH_STREAM_ERROR_NOT_SUPPORTED)
        .value("too_many_subscribers", TobiiResearchStreamError::TOBII_RESEARCH_STREAM_ERROR_TOO_MANY_SUBSCRIBERS)
        .value("internal_error", TobiiResearchStreamError::TOBII_RESEARCH_STREAM_ERROR_INTERNAL_ERROR)
        .value("user_error", TobiiResearchStreamError::TOBII_RESEARCH_STREAM_ERROR_USER_ERROR)
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
        ;
    // license
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
        ;
    py::enum_<TobiiResearchCalibrationStatus>(m, "calibration_status")
        .value("failure", TobiiResearchCalibrationStatus::TOBII_RESEARCH_CALIBRATION_FAILURE)
        .value("success", TobiiResearchCalibrationStatus::TOBII_RESEARCH_CALIBRATION_SUCCESS)
        .value("success_left_eye", TobiiResearchCalibrationStatus::TOBII_RESEARCH_CALIBRATION_SUCCESS_LEFT_EYE)
        .value("success_right_eye", TobiiResearchCalibrationStatus::TOBII_RESEARCH_CALIBRATION_SUCCESS_RIGHT_EYE)
        ;
    py::enum_<TobiiResearchSelectedEye>(m, "selected_eye")
        .value("left", TobiiResearchSelectedEye::TOBII_RESEARCH_SELECTED_EYE_LEFT)
        .value("right", TobiiResearchSelectedEye::TOBII_RESEARCH_SELECTED_EYE_RIGHT)
        .value("both", TobiiResearchSelectedEye::TOBII_RESEARCH_SELECTED_EYE_BOTH)
        ;
    py::enum_<TobiiResearchCalibrationEyeValidity>(m, "calibration_eye_validity")
        .value("invalid_and_not_used", TobiiResearchCalibrationEyeValidity::TOBII_RESEARCH_CALIBRATION_EYE_VALIDITY_INVALID_AND_NOT_USED)
        .value("valid_but_not_used", TobiiResearchCalibrationEyeValidity::TOBII_RESEARCH_CALIBRATION_EYE_VALIDITY_VALID_BUT_NOT_USED)
        .value("valid_and_used", TobiiResearchCalibrationEyeValidity::TOBII_RESEARCH_CALIBRATION_EYE_VALIDITY_VALID_AND_USED)
        .value("unknown", TobiiResearchCalibrationEyeValidity::TOBII_RESEARCH_CALIBRATION_EYE_VALIDITY_UNKNOWN)
        ;
    // streams
    py::enum_<TobiiResearchEyeImageType>(m, "eye_image_type")
        .value("full_image", TobiiResearchEyeImageType::TOBII_RESEARCH_EYE_IMAGE_TYPE_FULL)
        .value("cropped_image", TobiiResearchEyeImageType::TOBII_RESEARCH_EYE_IMAGE_TYPE_CROPPED)
        .value("multi_roi_image", TobiiResearchEyeImageType::TOBII_RESEARCH_EYE_IMAGE_TYPE_MULTI_ROI)
        .value("unknown", TobiiResearchEyeImageType::TOBII_RESEARCH_EYE_IMAGE_TYPE_UNKNOWN)
        ;
    py::enum_<TobiiResearchExternalSignalChangeType>(m, "external_signal_change_type")
        .value("value_changed", TobiiResearchExternalSignalChangeType::TOBII_RESEARCH_EXTERNAL_SIGNAL_VALUE_CHANGED)
        .value("initial_value", TobiiResearchExternalSignalChangeType::TOBII_RESEARCH_EXTERNAL_SIGNAL_INITIAL_VALUE)
        .value("connection_restored", TobiiResearchExternalSignalChangeType::TOBII_RESEARCH_EXTERNAL_SIGNAL_CONNECTION_RESTORED)
        ;
    py::enum_<TobiiResearchNotificationType>(m, "notification_type")
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
        ;

    //// global SDK functions
    m.def("get_SDK_version", []() { const auto v = Titta::getSDKVersion(); return string_format("%d.%d.%d.%d", v.major, v.minor, v.revision, v.build); });
    m.def("get_system_timestamp", &Titta::getSystemTimestamp);
    m.def("find_all_eye_trackers", []() {return StructVectorToList(Titta::findAllEyeTrackers()); });
    m.def("get_eye_tracker_from_address", [](std::string address_) {return StructToDict(Titta::getEyeTrackerFromAddress(std::move(address_))); });
    // logging
    m.def("start_logging", &Titta::startLogging,
        py::arg_v("initial_buffer_size", std::nullopt, "None"));
    m.def("get_log", [](bool clearLog_) -> py::list { return StructVectorToList(Titta::getLog(clearLog_)); },
        py::arg_v("clear_log", std::nullopt, "None"));
    m.def("stop_logging", &Titta::stopLogging);

    // main class
    auto cET = py::class_<Titta>(m, "EyeTracker")
        .def(py::init<std::string>(),"address"_a)

        .def("__repr__",
            [](Titta& instance_)
            {
                return string_format(
#ifdef NDEBUG
                    "<%s (%s, %s) @%.0f Hz at '%s'>",
#else
                    "<TittaPy.EyeTracker connected to '%s' (%s, %s) @%.0f Hz at '%s'>",
#endif
                    instance_.getEyeTrackerInfo().model.c_str(),
                    instance_.getEyeTrackerInfo().serialNumber.c_str(),
                    instance_.getEyeTrackerInfo().deviceName.c_str(),
                    instance_.getEyeTrackerInfo().frequency,
                    instance_.getEyeTrackerInfo().address.c_str()
                );
            })

        //// eye-tracker specific getters and setters
        .def_property_readonly("info", &Titta::getEyeTrackerInfo)
        .def_property         ("device_name",           [](Titta& instance_) { return                    instance_.getEyeTrackerInfo("deviceName").deviceName; }, &Titta::setDeviceName)
        .def_property_readonly("serial_number",         [](Titta& instance_) { return                    instance_.getEyeTrackerInfo("serialNumber").serialNumber; })
        .def_property_readonly("model",                 [](Titta& instance_) { return                    instance_.getEyeTrackerInfo("model").model; })
        .def_property_readonly("firmware_version",      [](Titta& instance_) { return                    instance_.getEyeTrackerInfo("firmwareVersion").firmwareVersion; })
        .def_property_readonly("runtime_version",       [](Titta& instance_) { return                    instance_.getEyeTrackerInfo("runtimeVersion").runtimeVersion; })
        .def_property_readonly("address",               [](Titta& instance_) { return                    instance_.getEyeTrackerInfo("address").address; })
        .def_property_readonly("capabilities",          [](Titta& instance_) { return CapabilitiesToList(instance_.getEyeTrackerInfo("capabilities").capabilities); })
        .def_property_readonly("supported_frequencies", [](Titta& instance_) { return                    instance_.getEyeTrackerInfo("supportedFrequencies").supportedFrequencies; })
        .def_property_readonly("supported_modes",       [](Titta& instance_) { return                    instance_.getEyeTrackerInfo("supportedModes").supportedModes; })
        .def_property         ("frequency",             [](Titta& instance_) { return                    instance_.getEyeTrackerInfo("frequency").frequency; }, &Titta::setFrequency)
        .def_property         ("tracking_mode",         [](Titta& instance_) { return                    instance_.getEyeTrackerInfo("trackingMode").trackingMode; }, &Titta::setTrackingMode)
        .def_property_readonly("track_box",             [](const Titta& instance_) { return StructToDict(instance_.getTrackBox()); })
        .def_property_readonly("display_area",          [](const Titta& instance_) { return StructToDict(instance_.getDisplayArea()); })
        // modifiers
        .def("apply_licenses", &Titta::applyLicenses,
            "licenses"_a)
        .def("clear_licenses", &Titta::clearLicenses)

        //// calibration
        .def("enter_calibration_mode", &Titta::enterCalibrationMode,
            "do_monocular"_a)
        .def("is_in_calibration_mode", &Titta::isInCalibrationMode,
            py::arg_v("issue_error_if_not_", std::nullopt, "None"))
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
        .def("calibration_retrieve_result", [](Titta& instance_) -> std::optional<py::dict>
            {
                const auto res = instance_.calibrationRetrieveResult(true);
                if (!res.has_value())
                    return {};

                return StructToDict(*res);
            })

        //// data streams
        // query if stream is supported
        .def("has_stream", [](const Titta& instance_, std::string stream_) -> bool { return instance_.hasStream(std::move(stream_), true); },
            "stream"_a)
        .def("has_stream", py::overload_cast<Titta::Stream>(&Titta::hasStream, py::const_),
            "stream"_a)

        // deal with eyeOpenness stream
        .def("set_include_eye_openness_in_gaze", &Titta::setIncludeEyeOpennessInGaze,
            "include"_a)

        // start stream
        .def("start", [](Titta& instance_, std::string stream_, const std::optional<size_t> init_buf_, const std::optional<bool> as_gif_) { return instance_.start(std::move(stream_), init_buf_, as_gif_, true); },
            "stream"_a, py::arg_v("initial_buffer_size", std::nullopt, "None"), py::arg_v("as_gif", std::nullopt, "None"))
        .def("start", py::overload_cast<Titta::Stream, std::optional<size_t>, std::optional<bool>>(&Titta::start),
            "stream"_a, py::arg_v("initial_buffer_size", std::nullopt, "None"), py::arg_v("as_gif", std::nullopt, "None"))

        // request stream state
        .def("is_recording", [](const Titta& instance_, std::string stream_) -> bool { return instance_.isRecording(std::move(stream_), true); },
            "stream"_a)
        .def("is_recording", py::overload_cast<Titta::Stream>(&Titta::isRecording, py::const_),
            "stream"_a)

        // consume samples (by default all)
        .def("consume_N",
            [](Titta& instance_, std::variant<std::string, Titta::Stream> stream_, const std::optional<size_t> NSamp_, std::optional<std::variant<std::string, Titta::BufferSide>> side_)
            -> py::dict
            {
                Titta::Stream stream;
                if (std::holds_alternative<std::string>(stream_))
                    stream = Titta::stringToStream(std::get<std::string>(stream_), true);
                else
                    stream = std::get<Titta::Stream>(stream_);

                std::optional<Titta::BufferSide> bufSide;
                if (side_.has_value())
                {
                    if (std::holds_alternative<std::string>(*side_))
                        bufSide = Titta::stringToBufferSide(std::get<std::string>(*side_));
                    else
                        bufSide = std::get<Titta::BufferSide>(*side_);
                }

                switch (stream)
                {
                case Titta::Stream::Gaze:
                case Titta::Stream::EyeOpenness:
                    return StructVectorToDict(instance_.consumeN<Titta::gaze>(NSamp_, bufSide));
                case Titta::Stream::EyeImage:
                    return StructVectorToDict(instance_.consumeN<Titta::eyeImage>(NSamp_, bufSide));
                case Titta::Stream::ExtSignal:
                    return StructVectorToDict(instance_.consumeN<Titta::extSignal>(NSamp_, bufSide));
                case Titta::Stream::TimeSync:
                    return StructVectorToDict(instance_.consumeN<Titta::timeSync>(NSamp_, bufSide));
                case Titta::Stream::Positioning:
                    return StructVectorToDict(instance_.consumeN<Titta::positioning>(NSamp_, bufSide));
                case Titta::Stream::Notification:
                    return StructVectorToDict(instance_.consumeN<Titta::notification>(NSamp_, bufSide));
                }
                return {};
            },
            "stream"_a, py::arg_v("N_samples", std::nullopt, "None"), py::arg_v("side", std::nullopt, "None"))
        // consume samples within given timestamps (inclusive, by default whole buffer)
        .def("consume_time_range",
            [](Titta& instance_, std::variant<std::string, Titta::Stream> stream_, const std::optional<int64_t> timeStart_, const std::optional<int64_t> timeEnd_)
            -> py::dict
            {
                Titta::Stream stream;
                if (std::holds_alternative<std::string>(stream_))
                    stream = Titta::stringToStream(std::get<std::string>(stream_), true);
                else
                    stream = std::get<Titta::Stream>(stream_);

                switch (stream)
                {
                case Titta::Stream::Gaze:
                case Titta::Stream::EyeOpenness:
                    return StructVectorToDict(instance_.consumeTimeRange<Titta::gaze>(timeStart_, timeEnd_));
                case Titta::Stream::EyeImage:
                    return StructVectorToDict(instance_.consumeTimeRange<Titta::eyeImage>(timeStart_, timeEnd_));
                case Titta::Stream::ExtSignal:
                    return StructVectorToDict(instance_.consumeTimeRange<Titta::extSignal>(timeStart_, timeEnd_));
                case Titta::Stream::TimeSync:
                    return StructVectorToDict(instance_.consumeTimeRange<Titta::timeSync>(timeStart_, timeEnd_));
                case Titta::Stream::Positioning:
                    DoExitWithMsg("Titta::cpp::consume_time_range: not supported for positioning stream.");
                case Titta::Stream::Notification:
                    return StructVectorToDict(instance_.consumeTimeRange<Titta::notification>(timeStart_, timeEnd_));
                }
                return {};
            },
            "stream"_a, py::arg_v("time_start", std::nullopt, "None"), py::arg_v("time_end", std::nullopt, "None"))

        // peek samples (by default only last one, can specify how many to peek, and from which side of buffer)
        .def("peek_N",
            [](Titta& instance_, std::variant<std::string, Titta::Stream> stream_, const std::optional<size_t> NSamp_, std::optional<std::variant<std::string, Titta::BufferSide>> side_)
            -> py::dict
            {
                Titta::Stream stream;
                if (std::holds_alternative<std::string>(stream_))
                    stream = Titta::stringToStream(std::get<std::string>(stream_), true);
                else
                    stream = std::get<Titta::Stream>(stream_);

                std::optional<Titta::BufferSide> bufSide;
                if (side_.has_value())
                {
                    if (std::holds_alternative<std::string>(*side_))
                        bufSide = Titta::stringToBufferSide(std::get<std::string>(*side_));
                    else
                        bufSide = std::get<Titta::BufferSide>(*side_);
                }

                switch (stream)
                {
                case Titta::Stream::Gaze:
                case Titta::Stream::EyeOpenness:
                    return StructVectorToDict(instance_.peekN<Titta::gaze>(NSamp_, bufSide));
                case Titta::Stream::EyeImage:
                    return StructVectorToDict(instance_.peekN<Titta::eyeImage>(NSamp_, bufSide));
                case Titta::Stream::ExtSignal:
                    return StructVectorToDict(instance_.peekN<Titta::extSignal>(NSamp_, bufSide));
                case Titta::Stream::TimeSync:
                    return StructVectorToDict(instance_.peekN<Titta::timeSync>(NSamp_, bufSide));
                case Titta::Stream::Positioning:
                    return StructVectorToDict(instance_.peekN<Titta::positioning>(NSamp_, bufSide));
                case Titta::Stream::Notification:
                    return StructVectorToDict(instance_.peekN<Titta::notification>(NSamp_, bufSide));
                }
                return {};
            },
            "stream"_a, py::arg_v("N_samples", std::nullopt, "None"), py::arg_v("side", std::nullopt, "None"))
        // peek samples within given timestamps (inclusive, by default whole buffer)
        .def("peek_time_range",
            [](Titta& instance_, std::variant<std::string, Titta::Stream> stream_, const std::optional<int64_t> timeStart_, const std::optional<int64_t> timeEnd_)
            -> py::dict
            {
                Titta::Stream stream;
                if (std::holds_alternative<std::string>(stream_))
                    stream = Titta::stringToStream(std::get<std::string>(stream_), true);
                else
                    stream = std::get<Titta::Stream>(stream_);

                switch (stream)
                {
                case Titta::Stream::Gaze:
                case Titta::Stream::EyeOpenness:
                    return StructVectorToDict(instance_.peekTimeRange<Titta::gaze>(timeStart_, timeEnd_));
                case Titta::Stream::EyeImage:
                    return StructVectorToDict(instance_.peekTimeRange<Titta::eyeImage>(timeStart_, timeEnd_));
                case Titta::Stream::ExtSignal:
                    return StructVectorToDict(instance_.peekTimeRange<Titta::extSignal>(timeStart_, timeEnd_));
                case Titta::Stream::TimeSync:
                    return StructVectorToDict(instance_.peekTimeRange<Titta::timeSync>(timeStart_, timeEnd_));
                case Titta::Stream::Positioning:
                    DoExitWithMsg("Titta::cpp::peek_time_range: not supported for positioning stream.");
                case Titta::Stream::Notification:
                    return StructVectorToDict(instance_.peekTimeRange<Titta::notification>(timeStart_, timeEnd_));
                }
                return {};
            },
            "stream"_a, py::arg_v("time_start", std::nullopt, "None"), py::arg_v("time_end", std::nullopt, "None"))

        // clear all buffer contents
        .def("clear", [](Titta& instance_, std::string stream_) { return instance_.clear(std::move(stream_), true); },
            "stream"_a)
        .def("clear", py::overload_cast<Titta::Stream>(&Titta::clear),
            "stream"_a)

        // clear contents buffer within given timestamps (inclusive, by default whole buffer)
        .def("clear_time_range", [](Titta& instance_, std::string stream_, const std::optional<int64_t> ts_, const std::optional<int64_t> te_) { return instance_.clearTimeRange(std::move(stream_), ts_, te_, true); },
            "stream"_a, py::arg_v("time_start", std::nullopt, "None"), py::arg_v("time_end", std::nullopt, "None"))
        .def("clear_time_range", py::overload_cast<Titta::Stream, std::optional<int64_t>, std::optional<int64_t>>(&Titta::clearTimeRange),
            "stream"_a, py::arg_v("time_start", std::nullopt, "None"), py::arg_v("time_end", std::nullopt, "None"))

        // stop, optionally deletes the buffer
        .def("stop", [](Titta& instance_, std::string stream_, const std::optional<bool> clearBuf_) { return instance_.stop(std::move(stream_), clearBuf_, true); },
            "stream"_a, py::arg_v("clear_buffer", std::nullopt, "None"))
        .def("stop", py::overload_cast<Titta::Stream, std::optional<bool>>(&Titta::stop),
            "stream"_a, py::arg_v("clear_buffer", std::nullopt, "None"))
        ;

    // nested enums
    py::enum_<Titta::Stream>(cET, "stream")
        .value(Titta::streamToString(Titta::Stream::Gaze, true).c_str(), Titta::Stream::Gaze)
        .value(Titta::streamToString(Titta::Stream::EyeOpenness, true).c_str(), Titta::Stream::EyeOpenness)
        .value(Titta::streamToString(Titta::Stream::EyeImage, true).c_str(), Titta::Stream::EyeImage)
        .value(Titta::streamToString(Titta::Stream::ExtSignal, true).c_str(), Titta::Stream::ExtSignal)
        .value(Titta::streamToString(Titta::Stream::TimeSync, true).c_str(), Titta::Stream::TimeSync)
        .value(Titta::streamToString(Titta::Stream::Positioning, true).c_str(), Titta::Stream::Positioning)
        .value(Titta::streamToString(Titta::Stream::Notification, true).c_str(), Titta::Stream::Notification)
        ;

    py::enum_<Titta::BufferSide>(cET, "buffer_side")
        .value(Titta::bufferSideToString(Titta::BufferSide::Start).c_str(), Titta::BufferSide::Start)
        .value(Titta::bufferSideToString(Titta::BufferSide::End).c_str(), Titta::BufferSide::End)
        ;

// set module version info
#define Q(x) #x
#define QUOTE(x) Q(x)
#ifdef VERSION_INFO
        m.attr("__version__") = QUOTE(VERSION_INFO);
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
