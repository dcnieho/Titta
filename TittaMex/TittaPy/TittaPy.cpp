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

#include "cpp_mex_helpers/is_container_trait.h"
#include "cpp_mex_helpers/get_field_nested.h"
#include "cpp_mex_helpers/mem_var_trait.h"
#include "tobii_elem_count.h"




template<typename ... Args>
std::string string_format(const std::string& format, Args ... args)
{
    auto size = static_cast<size_t>(snprintf(nullptr, 0, format.c_str(), args ...)) + 1; // Extra space for '\0'
    std::unique_ptr<char[]> buf(new char[size]);
    snprintf(buf.get(), size, format.c_str(), args ...);
    return std::string(buf.get(), buf.get() + size - 1); // We don't want the '\0' inside
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

template <> std::string toString<>(const TobiiResearchDisplayArea& instance_, std::string spacing)
{
    return string_format("display_area for %.1fmm x %.1fmm screen", instance_.width, instance_.height);
}

template <> std::string toString<>(const TobiiResearchCalibrationEyeData& instance_, std::string spacing)
{
    return string_format("calibration_eye_data (%s) at [%.4f, %.4f]", calibrationEyeValidityToString(instance_.validity), instance_.position_on_display_area.x, instance_.position_on_display_area.y);
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
    auto ret = string_format("calibration_point at [%.4f, %.4f] with %Iu samples, of which %d valid for left eye and %d valid for right eye", instance_.position_on_display_area.x, instance_.position_on_display_area.y, instance_.calibration_samples.size(), nValidLeft, nValidRight);
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
    return string_format(
#ifdef NDEBUG
        "[%.3f, %.3f, %.3f] mm",
#else
        "<TittaPy.point_3D at [%.3f, %.3f, %.3f] mm>",
#endif
        instance_.x, instance_.y, instance_.z
    );
}
template <> std::string toString<>(const TobiiResearchNormalizedPoint2D& instance_, std::string spacing)
{
    return string_format(
#ifdef NDEBUG
        "[%.3f, %.3f] mm",
#else
        "<TittaPy.point_2D_norm at [%.3f, %.3f] mm>",
#endif
        instance_.x, instance_.y
    );
}


// default output is storage type corresponding to the type of the member variable accessed through this function, but it can be overridden through type tag dispatch (see nested_field::getWrapper implementation)
template<bool UseArray, typename Cont, typename... Fs>
requires Container<Cont>
void FieldToNpArray(py::dict& out_, const Cont& data_, const std::string& name_, Fs... fields)
{
    using V = typename Cont::value_type;
    using U = decltype(nested_field::getWrapper(std::declval<V>(), fields...));
    auto nElem = static_cast<py::ssize_t>(data_.size());

    if constexpr (UseArray)
    {
        py::array_t<U> a;
        a.resize({ nElem });

        if (data_.size())
        {
            auto storage = a.mutable_data();
            for (auto&& item : data_)
                (*storage++) = nested_field::getWrapper(item, fields...);
        }

        out_[name_.c_str()] = a;
    }
    else
    {
        py::list l;

        if (data_.size())
            for (auto&& item : data_)
                l.append(nested_field::getWrapper(item, fields...));

        out_[name_.c_str()] = l;
    }
}

template<typename Cont, typename... Fs>
requires Container<Cont>
void TobiiFieldToNpArray(py::dict& out_, const Cont& data_, const std::string& name_, Fs... fields)
{
    using V = typename Cont::value_type;
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

py::array_t<uint8_t> imageToNumpy(const TobiiTypes::eyeImage e_)
{
    py::array_t<uint8_t> a;
    a.resize({ e_.height, e_.width });
    std::memcpy(a.mutable_data(), e_.data(), e_.data_size);
    return a;
}
void outputEyeImages(py::dict& out_, const std::vector<Titta::eyeImage>& data_, const std::string& name_, const bool noneGif_)
{
    if (data_.empty())
    {
        out_[name_.c_str()] = py::array_t<uint8_t>();
        return;
    }

    // 1. see if all same size, then we can put them in one big matrix
    auto sz = data_[0].data_size;
    bool same = allEquals(data_, &Titta::eyeImage::data_size, sz);
    // 2. then copy over the images to the dict
    if (data_[0].bits_per_pixel + data_[0].padding_per_pixel != 8)
        throw "Titta: outputEyeImages: non-8bit images not implemented";
    if (same)
    {
        py::array_t<uint8_t> a;
        a.resize({ static_cast<py::ssize_t>(data_[0].width), static_cast<py::ssize_t>(data_[0].height), static_cast<py::ssize_t>(data_.size()) });
        auto storage = a.mutable_data();
        size_t i = 0;
        for (auto& frame : data_)
            std::memcpy(storage + (i++) * sz, frame.data(), frame.data_size);
        out_[name_.c_str()] = a;
    }
    else
    {
        py::list l;
        for (auto& frame : data_)
        {
            if (!frame.is_gif)
                l.append(imageToNumpy(frame));
            else
                l.append(py::array_t<uint8_t>(static_cast<py::ssize_t>(frame.data_size), static_cast<uint8_t*>(frame.data())));
        }
    }
}


template<typename Cont>
requires Container<Cont>
py::dict StructVectorToDict(const Cont& data_);

template <> py::dict StructVectorToDict(const std::vector<Titta::gaze>& data_)
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

template <> py::dict StructVectorToDict(const std::vector<Titta::eyeImage>& data_)
{
    py::dict out;

    // check if all gif, then don't output unneeded fields
    bool allGif = allEquals(data_, &Titta::eyeImage::is_gif, true);
    bool noneGif= allEquals(data_, &Titta::eyeImage::is_gif, false);

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
    outputEyeImages(out, data_, "image"   , noneGif);

    return out;
}

template <> py::dict StructVectorToDict(const std::vector<Titta::extSignal>& data_)
{
    py::dict out;

    FieldToNpArray<true>(out, data_, "device_time_stamp", &Titta::extSignal::device_time_stamp);
    FieldToNpArray<true>(out, data_, "system_time_stamp", &Titta::extSignal::system_time_stamp);
    FieldToNpArray<true>(out, data_, "value"            , &Titta::extSignal::value);
    FieldToNpArray<false>(out, data_, "change_type"     , &Titta::extSignal::change_type);

    return out;
}

template <> py::dict StructVectorToDict(const std::vector<Titta::timeSync>& data_)
{
    py::dict out;

    FieldToNpArray<true>(out, data_, "system_request_time_stamp" , &Titta::timeSync::system_request_time_stamp);
    FieldToNpArray<true>(out, data_, "device_time_stamp"         , &Titta::timeSync::device_time_stamp);
    FieldToNpArray<true>(out, data_, "system_response_time_stamp", &Titta::timeSync::system_response_time_stamp);

    return out;
}

template <> py::dict StructVectorToDict(const std::vector<Titta::positioning>& data_)
{
    py::dict out;

    TobiiFieldToNpArray(out, data_, "left_user_position"        , &Titta::positioning::left_eye , &TobiiResearchEyeUserPositionGuide::user_position);
    FieldToNpArray<true>(out, data_, "left_user_position_valid" , &Titta::positioning::left_eye , &TobiiResearchEyeUserPositionGuide::validity, TOBII_RESEARCH_VALIDITY_VALID);
    TobiiFieldToNpArray(out, data_, "right_user_position"       , &Titta::positioning::right_eye, &TobiiResearchEyeUserPositionGuide::user_position);
    FieldToNpArray<true>(out, data_, "right_user_position_valid", &Titta::positioning::right_eye, &TobiiResearchEyeUserPositionGuide::validity, TOBII_RESEARCH_VALIDITY_VALID);

    return out;
}

template <> py::dict StructVectorToDict(const std::vector<Titta::notification>& data_)
{
    py::dict out;

    FieldToNpArray<true> (out, data_, "system_time_stamp" , &Titta::notification::system_time_stamp);
    FieldToNpArray<false>(out, data_, "notification_type" , &Titta::notification::notification_type);
    FieldToNpArray<true> (out, data_, "output_frequency"  , &Titta::notification::output_frequency);
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

template <> py::dict StructVectorToDict(const std::vector<std::variant<TobiiTypes::logMessage, TobiiTypes::streamErrorMessage>>& data_)
{
    py::list out;

    if (data_.size())
        for (auto&& item : data_)
            out.append(std::visit([](auto& a) {return StructToDict(a); }, item));

    return out;
}

void FieldToNpArray(py::dict& out_, const std::vector<TobiiResearchCalibrationSample>& data_, const std::string& name_, TobiiResearchCalibrationEyeData TobiiResearchCalibrationSample::* field_)
{
    TobiiFieldToNpArray  (out_, data_, name_ + "_position_on_display_area", field_, &TobiiResearchCalibrationEyeData::position_on_display_area);
    FieldToNpArray<false>(out_, data_, name_ + "_validity"                , field_, &TobiiResearchCalibrationEyeData::validity);
}

template <> py::dict StructVectorToDict(const std::vector<TobiiResearchCalibrationSample>& data_)
{
    py::dict out;

    FieldToNpArray(out, data_, "samples_left" , &TobiiResearchCalibrationSample::left_eye);
    FieldToNpArray(out, data_, "samples_right", &TobiiResearchCalibrationSample::right_eye);

    return out;
}



// start module scope
#ifdef NDEBUG
#   define MODULE_NAME TittaPy
#else
#   define MODULE_NAME TittaPy_d
#endif
PYBIND11_MODULE(MODULE_NAME, m)
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
                    throw std::runtime_error("Invalid state! (SDK_version)");

                TobiiResearchSDKVersion p{ t[0].cast<int>(),t[1].cast<int>(),t[2].cast<int>(),t[3].cast<int>() };
                return p;
            }
        ))
        .def("__repr__", [](const TobiiResearchSDKVersion& instance_) { return toString(instance_); })
        ;

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

    py::class_<TobiiTypes::eyeTracker>(m, "eye_tracker_info")
        .def_readonly("device_name", &TobiiTypes::eyeTracker::deviceName)
        .def_readonly("serial_number", &TobiiTypes::eyeTracker::serialNumber)
        .def_readonly("model", &TobiiTypes::eyeTracker::model)
        .def_readonly("firmware_version", &TobiiTypes::eyeTracker::firmwareVersion)
        .def_readonly("runtime_version", &TobiiTypes::eyeTracker::runtimeVersion)
        .def_readonly("address", &TobiiTypes::eyeTracker::address)
        .def_readonly("frequency", &TobiiTypes::eyeTracker::frequency)
        .def_readonly("tracking_mode", &TobiiTypes::eyeTracker::trackingMode)
        .def_readonly("capabilities", &TobiiTypes::eyeTracker::capabilities)
        .def_readonly("supported_frequencies", &TobiiTypes::eyeTracker::supportedFrequencies)
        .def_readonly("supported_modes", &TobiiTypes::eyeTracker::supportedModes)
        .def(py::pickle(
            [](const TobiiTypes::eyeTracker& p) { // __getstate__
                return py::make_tuple(p.deviceName, p.serialNumber, p.model, p.firmwareVersion, p.runtimeVersion, p.address, p.frequency, p.trackingMode, p.capabilities, p.supportedFrequencies, p.supportedModes);
            },
            [](py::tuple t) { // __setstate__
                if (t.size() != 11)
                    throw std::runtime_error("Invalid state! (eye_tracker_info)");

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
                    throw std::runtime_error("Invalid state! (track_box)");

                TobiiResearchTrackBox p{ t[0].cast<TobiiResearchPoint3D>(),t[1].cast<TobiiResearchPoint3D>(),t[2].cast<TobiiResearchPoint3D>(),t[3].cast<TobiiResearchPoint3D>(),t[4].cast<TobiiResearchPoint3D>(),t[5].cast<TobiiResearchPoint3D>(),t[6].cast<TobiiResearchPoint3D>(),t[7].cast<TobiiResearchPoint3D>() };
                return p;
            }
        ))
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
                    throw std::runtime_error("Invalid state! (display_area)");

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
    py::class_<TobiiTypes::CalibrationPoint>(m, "calibration_point")
        .def_readwrite("position_on_display_area", &TobiiTypes::CalibrationPoint::position_on_display_area)
        .def_property_readonly("samples", [](const TobiiTypes::CalibrationPoint& instance_) -> py::dict
            { return StructVectorToDict(instance_.calibration_samples); })
        //.def_readwrite("samples", &TobiiTypes::CalibrationPoint::calibration_samples)
        .def(py::pickle(
            [](const TobiiTypes::CalibrationPoint& p) { // __getstate__
                return py::make_tuple(p.position_on_display_area, p.calibration_samples);
            },
            [](py::tuple t) { // __setstate__
                if (t.size() != 2)
                    throw std::runtime_error("Invalid state! (calibration_point)");

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
                    throw std::runtime_error("Invalid state! (calibration_result)");

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
                    throw std::runtime_error("Invalid state! (calibration_work_item)");

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
                    throw std::runtime_error("Invalid state! (calibration_work_result)");

                TobiiTypes::CalibrationWorkResult p{ t[0].cast<TobiiTypes::CalibrationWorkItem>(),static_cast<TobiiResearchStatus>(t[1].cast<int>()),t[2].cast<std::string>(),t[3].cast<std::optional<TobiiTypes::CalibrationResult>>(),t[4].cast<std::optional<std::vector<uint8_t>>>() };
                return p;
            }
        ))
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
                    throw std::runtime_error("Invalid state! (point_3D)");

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
                    throw std::runtime_error("Invalid state! (point_2D_norm)");

                TobiiResearchNormalizedPoint2D p{ t[0].cast<float>(),t[1].cast<float>() };
                return p;
            }
        ))
        .def("__repr__",[](const TobiiResearchNormalizedPoint2D& instance_){ return toString(instance_); })
        ;

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
    m.def("get_SDK_version", &Titta::getSDKVersion);
    m.def("get_system_timestamp", &Titta::getSystemTimestamp);
    m.def("find_all_eye_trackers", &Titta::findAllEyeTrackers);
    // logging
    m.def("start_logging", &Titta::startLogging,
        py::arg_v("initial_buffer_size", std::nullopt, "None"));
    m.def("get_log", [](bool clearLog_) -> py::list { return StructVectorToDict(Titta::getLog(clearLog_)); },
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
                    "%s (%s, %s) @%.0f Hz at '%s'",
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
        .def_property("device_name", [](Titta& instance_) { return instance_.getEyeTrackerInfo("deviceName").deviceName; }, &Titta::setDeviceName)
        .def_property_readonly("serial_number", [](Titta& instance_) { return instance_.getEyeTrackerInfo("serialNumber").serialNumber; })
        .def_property_readonly("model", [](Titta& instance_) { return instance_.getEyeTrackerInfo("model").model; })
        .def_property_readonly("firmware_version", [](Titta& instance_) { return instance_.getEyeTrackerInfo("firmwareVersion").firmwareVersion; })
        .def_property_readonly("runtime_version", [](Titta& instance_) { return instance_.getEyeTrackerInfo("runtimeVersion").runtimeVersion; })
        .def_property_readonly("address", [](Titta& instance_) { return instance_.getEyeTrackerInfo("address").address; })
        .def_property_readonly("capabilities", [](Titta& instance_) { return instance_.getEyeTrackerInfo("capabilities").capabilities; })
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
            "do_monocular"_a)
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
            "make_string"_a=false)

        //// data streams
        // query if stream is supported
        .def("has_stream", [](const Titta& instance, std::string stream_) -> bool { return instance.hasStream(stream_, true); },
            "stream"_a)
        .def("has_stream", py::overload_cast<Titta::Stream>(&Titta::hasStream, py::const_),
            "stream"_a)

        // deal with eyeOpenness stream
        .def("set_include_eye_openness_in_gaze", &Titta::setIncludeEyeOpennessInGaze,
            "include"_a)

        // start stream
        .def("start", [](Titta& instance, std::string stream_, std::optional<size_t> init_buf_, std::optional<bool> as_gif_) { return instance.start(stream_, init_buf_, as_gif_, true); },
            "stream"_a, py::arg_v("initial_buffer_size", std::nullopt, "None"), py::arg_v("as_gif", std::nullopt, "None"))
        .def("start", py::overload_cast<Titta::Stream, std::optional<size_t>, std::optional<bool>>(&Titta::start),
            "stream"_a, py::arg_v("initial_buffer_size", std::nullopt, "None"), py::arg_v("as_gif", std::nullopt, "None"))

        // request stream state
        .def("is_recording", [](const Titta& instance, std::string stream_) -> bool { return instance.isRecording(stream_, true); },
            "stream"_a)
        .def("is_recording", py::overload_cast<Titta::Stream>(&Titta::isRecording, py::const_),
            "stream"_a)

        // consume samples (by default all)
        .def("consume_N",
            [](Titta& instance_, std::variant<std::string, Titta::Stream> stream_, std::optional<size_t> NSamp_, std::optional<std::variant<std::string, Titta::BufferSide>> side_)
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
            [](Titta& instance_, std::variant<std::string, Titta::Stream> stream_, std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_)
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
            [](Titta& instance_, std::variant<std::string, Titta::Stream> stream_, std::optional<size_t> NSamp_, std::optional<std::variant<std::string, Titta::BufferSide>> side_)
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
            [](Titta& instance_, std::variant<std::string, Titta::Stream> stream_, std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_)
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
        .def("clear", [](Titta& instance, std::string stream_) { return instance.clear(stream_, true); },
            "stream"_a)
        .def("clear", py::overload_cast<Titta::Stream>(&Titta::clear),
            "stream"_a)

        // clear contents buffer within given timestamps (inclusive, by default whole buffer)
        .def("clear_time_range", [](Titta& instance, std::string stream_, std::optional<int64_t> ts_, std::optional<int64_t> te_) { return instance.clearTimeRange(stream_, ts_, te_, true); },
            "stream"_a, py::arg_v("time_start", std::nullopt, "None"), py::arg_v("time_end", std::nullopt, "None"))
        .def("clear_time_range", py::overload_cast<Titta::Stream, std::optional<int64_t>, std::optional<int64_t>>(&Titta::clearTimeRange),
            "stream"_a, py::arg_v("time_start", std::nullopt, "None"), py::arg_v("time_end", std::nullopt, "None"))

        // stop, optionally deletes the buffer
        .def("stop", [](Titta& instance, std::string stream_, std::optional<bool> clearBuf_) { return instance.stop(stream_, clearBuf_, true); },
            "stream"_a, py::arg_v("clear_buffer", std::nullopt, "None"))
        .def("stop", py::overload_cast<Titta::Stream, std::optional<bool>>(&Titta::stop),
            "stream"_a, py::arg_v("clear_buffer", std::nullopt, "None"))
        ;


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