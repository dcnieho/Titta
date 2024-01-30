#define _CRT_SECURE_NO_WARNINGS
#include "Titta/Titta.h"
#include "Titta/utils.h"
#include "TittaLSL/TittaLSL.h"

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
void FieldToNpArray(py::dict& out_, const std::vector<V>& data_, const std::string& name_, Fs... fields)
{
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

template<typename V, typename... Fs>
void TobiiFieldToNpArray(py::dict& out_, const std::vector<V>& data_, const std::string& name_, Fs... fields_)
{
    // get type member variable accessed through the last pointer-to-member-variable in the parameter pack (this is not necessarily the last type in the parameter pack as that can also be the type tag if the user explicitly requested a return type)
    using memVar = std::conditional_t<std::is_member_object_pointer_v<last<0, V, Fs...>>, last<0, V, Fs...>, last<1, V, Fs...>>;
    using retT = memVarType_t<memVar>;
    // based on type, get number of rows for output
    constexpr auto numElements = getNumElements<retT>();

    // this is one of the 2D/3D point types
    // determine what return type we get
    // NB: appending extra field to access leads to wrong order if type tag was provided by user. nested_field::getWrapper detects this and corrects for it
    using U = decltype(nested_field::getWrapper(std::declval<V>(), std::forward<Fs>(fields_)..., &retT::x));

    FieldToNpArray<true>(out_, data_, name_ + "_x", std::forward<Fs>(fields_)..., &retT::x);
    FieldToNpArray<true>(out_, data_, name_ + "_y", std::forward<Fs>(fields_)..., &retT::y);
    if constexpr (numElements == 3)
        FieldToNpArray<true>(out_, data_, name_ + "_z", std::forward<Fs>(fields_)..., &retT::z);
}

void FieldToNpArray(py::dict& out_, const std::vector<TittaLSL::Receiver::gaze>& data_, const std::string& name_, TobiiTypes::eyeData Titta::gaze::* field_)
{
    // 1. gaze_point
    auto localName = name_ + "_gaze_point_";
    // 1.1 gaze_point_on_display_area
    TobiiFieldToNpArray (out_, data_, localName+"on_display_area"    , &TittaLSL::Receiver::gaze::gazeData, field_, &TobiiTypes::eyeData::gaze_point, &TobiiTypes::gazePoint::position_on_display_area);
    // 1.2 gaze_point_in_user_coordinates
    TobiiFieldToNpArray (out_, data_, localName+"in_user_coordinates", &TittaLSL::Receiver::gaze::gazeData, field_, &TobiiTypes::eyeData::gaze_point, &TobiiTypes::gazePoint::position_in_user_coordinates);
    // 1.3 gaze_point_valid
    FieldToNpArray<true>(out_, data_, localName+"valid"              , &TittaLSL::Receiver::gaze::gazeData, field_, &TobiiTypes::eyeData::gaze_point, &TobiiTypes::gazePoint::validity, TOBII_RESEARCH_VALIDITY_VALID);
    // 1.4 gaze_point_available
    FieldToNpArray<true>(out_, data_, localName+"available"          , &TittaLSL::Receiver::gaze::gazeData, field_, &TobiiTypes::eyeData::gaze_point, &TobiiTypes::gazePoint::available);

    // 2. pupil
    localName = name_ + "_pupil_";
    // 2.1 pupil_diameter
    FieldToNpArray<true>(out_, data_, localName + "diameter" , &TittaLSL::Receiver::gaze::gazeData, field_, &TobiiTypes::eyeData::pupil, &TobiiTypes::pupilData::diameter);
    // 2.2 pupil_valid
    FieldToNpArray<true>(out_, data_, localName + "valid"    , &TittaLSL::Receiver::gaze::gazeData, field_, &TobiiTypes::eyeData::pupil, &TobiiTypes::pupilData::validity, TOBII_RESEARCH_VALIDITY_VALID);
    // 2.3 pupil_available
    FieldToNpArray<true>(out_, data_, localName + "available", &TittaLSL::Receiver::gaze::gazeData, field_, &TobiiTypes::eyeData::pupil, &TobiiTypes::pupilData::available);

    // 3. gazeOrigin
    localName = name_ + "_gaze_origin_";
    // 3.1 gaze_origin_in_user_coordinates
    TobiiFieldToNpArray (out_, data_, localName + "in_user_coordinates"     , &TittaLSL::Receiver::gaze::gazeData, field_, &TobiiTypes::eyeData::gaze_origin, &TobiiTypes::gazeOrigin::position_in_user_coordinates);
    // 3.2 gaze_origin_in_track_box_coordinates
    TobiiFieldToNpArray (out_, data_, localName + "in_track_box_coordinates", &TittaLSL::Receiver::gaze::gazeData, field_, &TobiiTypes::eyeData::gaze_origin, &TobiiTypes::gazeOrigin::position_in_track_box_coordinates);
    // 3.3 gaze_origin_valid
    FieldToNpArray<true>(out_, data_, localName + "valid"                   , &TittaLSL::Receiver::gaze::gazeData, field_, &TobiiTypes::eyeData::gaze_origin, &TobiiTypes::gazeOrigin::validity, TOBII_RESEARCH_VALIDITY_VALID);
    // 3.4 gaze_origin_available
    FieldToNpArray<true>(out_, data_, localName + "available"               , &TittaLSL::Receiver::gaze::gazeData, field_, &TobiiTypes::eyeData::gaze_origin, &TobiiTypes::gazeOrigin::available);

    // 4. eyeOpenness
    localName = name_ + "_eye_openness_";
    // 4.1 eye_openness_diameter
    FieldToNpArray<true>(out_, data_, localName + "diameter"  , &TittaLSL::Receiver::gaze::gazeData, field_, &TobiiTypes::eyeData::eye_openness, &TobiiTypes::eyeOpenness::diameter);
    // 4.2 eye_openness_valid
    FieldToNpArray<true>(out_, data_, localName + "valid"     , &TittaLSL::Receiver::gaze::gazeData, field_, &TobiiTypes::eyeData::eye_openness, &TobiiTypes::eyeOpenness::validity, TOBII_RESEARCH_VALIDITY_VALID);
    // 4.3 eye_openness_available
    FieldToNpArray<true>(out_, data_, localName + "available" , &TittaLSL::Receiver::gaze::gazeData, field_, &TobiiTypes::eyeData::eye_openness, &TobiiTypes::eyeOpenness::available);
}


// eye images
template <typename S, typename T, typename SS, typename TT, typename R>
bool allEquals(const std::vector<S>& data_, T S::* field_, TT SS::* field2_, const R& ref_)
{
    for (auto& frame : data_)
        if (frame.*field_.*field2_ != ref_)
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
void outputEyeImages(py::dict& out_, const std::vector<TittaLSL::Receiver::eyeImage>& data_, const std::string& name_)
{
    if (data_.empty())
    {
        out_[name_.c_str()] = py::list();
        return;
    }

    py::list l;
    for (const auto& frame : data_)
    {
        if (!frame.eyeImageData.is_gif)
            l.append(imageToNumpy(frame.eyeImageData));
        else
            l.append(py::array_t<uint8_t>(static_cast<py::ssize_t>(frame.eyeImageData.data_size), static_cast<uint8_t*>(frame.eyeImageData.data())));
    }
    out_[name_.c_str()] = l;
}



py::dict StructVectorToDict(std::vector<TittaLSL::Receiver::gaze>&& data_)
{
    py::dict out;

    // 1. remote system timestamps
    FieldToNpArray<true>(out, data_, "remote_system_time_stamp", &TittaLSL::Receiver::gaze::remoteSystemTimeStamp);
    // 2. local system timestamps
    FieldToNpArray<true>(out, data_, "local_system_time_stamp" , &TittaLSL::Receiver::gaze::localSystemTimeStamp);
    // 3. device timestamps
    FieldToNpArray<true>(out, data_, "device_time_stamp", &TittaLSL::Receiver::gaze::gazeData, &Titta::gaze::device_time_stamp);
    // 4. system timestamps
    FieldToNpArray<true>(out, data_, "system_time_stamp", &TittaLSL::Receiver::gaze::gazeData, &Titta::gaze::system_time_stamp);
    // 5. left  eye data
    FieldToNpArray(out, data_, "left" , &Titta::gaze::left_eye);
    // 6. right eye data
    FieldToNpArray(out, data_, "right", &Titta::gaze::right_eye);

    return out;
}

py::dict StructVectorToDict(std::vector<TittaLSL::Receiver::eyeImage>&& data_)
{
    py::dict out;

    // check if all gif, then don't output unneeded fields
    const bool allGif = allEquals(data_, &TittaLSL::Receiver::eyeImage::eyeImageData, &Titta::eyeImage::is_gif, true);

    FieldToNpArray<true>(out, data_, "remote_system_time_stamp" , &TittaLSL::Receiver::eyeImage::remoteSystemTimeStamp);
    FieldToNpArray<true>(out, data_, "local_system_time_stamp"  , &TittaLSL::Receiver::eyeImage::localSystemTimeStamp);
    FieldToNpArray<true>(out, data_, "device_time_stamp", &TittaLSL::Receiver::eyeImage::eyeImageData, &Titta::eyeImage::device_time_stamp);
    FieldToNpArray<true>(out, data_, "system_time_stamp", &TittaLSL::Receiver::eyeImage::eyeImageData, &Titta::eyeImage::system_time_stamp);
    FieldToNpArray<true>(out, data_, "region_id"        , &TittaLSL::Receiver::eyeImage::eyeImageData, &Titta::eyeImage::region_id);
    FieldToNpArray<true>(out, data_, "region_top"       , &TittaLSL::Receiver::eyeImage::eyeImageData, &Titta::eyeImage::region_top);
    FieldToNpArray<true>(out, data_, "region_left"      , &TittaLSL::Receiver::eyeImage::eyeImageData, &Titta::eyeImage::region_left);
    if (!allGif)
    {
        FieldToNpArray<true>(out, data_, "bits_per_pixel"   , &TittaLSL::Receiver::eyeImage::eyeImageData, &Titta::eyeImage::bits_per_pixel);
        FieldToNpArray<true>(out, data_, "padding_per_pixel", &TittaLSL::Receiver::eyeImage::eyeImageData, &Titta::eyeImage::padding_per_pixel);
    }
    FieldToNpArray<false>(out, data_, "type"     , &TittaLSL::Receiver::eyeImage::eyeImageData, &Titta::eyeImage::type);
    FieldToNpArray<true> (out, data_, "camera_id", &TittaLSL::Receiver::eyeImage::eyeImageData, &Titta::eyeImage::camera_id);
    FieldToNpArray<true> (out, data_, "is_gif"   , &TittaLSL::Receiver::eyeImage::eyeImageData, &Titta::eyeImage::is_gif);
    outputEyeImages(out, data_, "image");

    return out;
}

py::dict StructVectorToDict(std::vector<TittaLSL::Receiver::extSignal>&& data_)
{
    py::dict out;

    FieldToNpArray<true>(out, data_, "remote_system_time_stamp", &TittaLSL::Receiver::extSignal::remoteSystemTimeStamp);
    FieldToNpArray<true>(out, data_, "local_system_time_stamp" , &TittaLSL::Receiver::extSignal::localSystemTimeStamp);
    FieldToNpArray<true>(out, data_, "device_time_stamp", &TittaLSL::Receiver::extSignal::extSignalData, &Titta::extSignal::device_time_stamp);
    FieldToNpArray<true>(out, data_, "system_time_stamp", &TittaLSL::Receiver::extSignal::extSignalData, &Titta::extSignal::system_time_stamp);
    FieldToNpArray<true>(out, data_, "value"            , &TittaLSL::Receiver::extSignal::extSignalData, &Titta::extSignal::value);
    FieldToNpArray<false>(out, data_, "change_type"     , &TittaLSL::Receiver::extSignal::extSignalData, &Titta::extSignal::change_type);

    return out;
}

py::dict StructVectorToDict(std::vector<TittaLSL::Receiver::timeSync>&& data_)
{
    py::dict out;

    FieldToNpArray<true>(out, data_, "remote_system_time_stamp", &TittaLSL::Receiver::timeSync::remoteSystemTimeStamp);
    FieldToNpArray<true>(out, data_, "local_system_time_stamp" , &TittaLSL::Receiver::timeSync::localSystemTimeStamp);
    FieldToNpArray<true>(out, data_, "system_request_time_stamp" , &TittaLSL::Receiver::timeSync::timeSyncData, &Titta::timeSync::system_request_time_stamp);
    FieldToNpArray<true>(out, data_, "device_time_stamp"         , &TittaLSL::Receiver::timeSync::timeSyncData, &Titta::timeSync::device_time_stamp);
    FieldToNpArray<true>(out, data_, "system_response_time_stamp", &TittaLSL::Receiver::timeSync::timeSyncData, &Titta::timeSync::system_response_time_stamp);

    return out;
}

py::dict StructVectorToDict(std::vector<TittaLSL::Receiver::positioning>&& data_)
{
    py::dict out;

    FieldToNpArray<true>(out, data_, "remote_system_time_stamp" , &TittaLSL::Receiver::positioning::remoteSystemTimeStamp);
    FieldToNpArray<true>(out, data_, "local_system_time_stamp"  , &TittaLSL::Receiver::positioning::localSystemTimeStamp);
    TobiiFieldToNpArray(out, data_, "left_user_position"        , &TittaLSL::Receiver::positioning::positioningData, &Titta::positioning::left_eye, &TobiiResearchEyeUserPositionGuide::user_position);
    FieldToNpArray<true>(out, data_, "left_user_position_valid" , &TittaLSL::Receiver::positioning::positioningData, &Titta::positioning::left_eye , &TobiiResearchEyeUserPositionGuide::validity, TOBII_RESEARCH_VALIDITY_VALID);
    TobiiFieldToNpArray(out, data_, "right_user_position"       , &TittaLSL::Receiver::positioning::positioningData, &Titta::positioning::right_eye, &TobiiResearchEyeUserPositionGuide::user_position);
    FieldToNpArray<true>(out, data_, "right_user_position_valid", &TittaLSL::Receiver::positioning::positioningData, &Titta::positioning::right_eye, &TobiiResearchEyeUserPositionGuide::validity, TOBII_RESEARCH_VALIDITY_VALID);

    return out;
}

py::dict StructToDict(const lsl::stream_info& data_)
{
    py::dict d;
    d["name"] = data_.name();
    d["type"] = data_.type();
    d["channel_count"] = data_.channel_count();
    d["nominal_srate"] = data_.nominal_srate();
    d["channel_format"] = data_.channel_format();
    d["source_id"] = data_.source_id();
    d["version"] = data_.version();
    d["created_at"] = data_.created_at();
    d["uid"] = data_.uid();
    d["session_id"] = data_.session_id();
    d["hostname"] = data_.hostname();
    d["xml"] = data_.as_xml();
    d["channel_bytes"] = data_.channel_bytes();
    d["sample_bytes"] = data_.sample_bytes();
    return d;
}

py::list StructVectorToList(std::vector<lsl::stream_info>&& data_)
{
    py::list out;

    for (auto&& i : data_)
        out.append(StructToDict(i));

    return out;
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
}


// start module scope
#ifdef NDEBUG
#   define MODULE_NAME TittaLSLPy
#else
#   define MODULE_NAME TittaLSLPy_d
#endif
PYBIND11_MODULE(MODULE_NAME, m)
{
    // We must import TittaPy, as this defines some of the enums and other data types we use here.
    // Must be done this way, as defining them hear as well leads to a double definition error when both this module and TittaPy are imported (likely!).
    py::module_::import("TittaPy");

    py::enum_<lsl::channel_format_t>(m, "channel_format")
        .value("float32", lsl::cf_float32)
        .value("double64", lsl::cf_double64)
        .value("string", lsl::cf_string)
        .value("int32", lsl::cf_int32)
        .value("int16", lsl::cf_int16)
        .value("int8", lsl::cf_int8)
        .value("int64", lsl::cf_int64)
        .value("undefined", lsl::cf_undefined)
        ;
    // NB: stream type is already exported by TittaPy, no need for us to also create it (actually not possible, would clash on import)

    //// global SDK functions
    m.def("get_Tobii_SDK_version", []() { const auto v = TittaLSL::getTobiiSDKVersion(); return string_format("%d.%d.%d.%d", v.major, v.minor, v.revision, v.build); });
    m.def("get_LSL_version", &TittaLSL::getLSLVersion);

    // outlets
    auto cStreamer = py::class_<TittaLSL::Sender>(m, "Sender")
        .def(py::init<std::string>(), "address"_a)

        .def("__repr__",
            [](TittaLSL::Sender& instance_)
            {
                const auto et = instance_.getEyeTracker();
                return string_format("<TittaLSL.Sender (%s (%s) @ %.0f)>",
                    et.model.c_str(),
                    et.serialNumber.c_str(),
                    et.frequency
                    );
            })

        .def("get_eye_tracker", [](TittaLSL::Sender& instance_) { return StructToDict(instance_.getEyeTracker()); })
        .def("get_stream_source_id", [](const TittaLSL::Sender& instance_, std::string stream_) -> std::string { return instance_.getStreamSourceID(std::move(stream_), true); },
            "stream"_a)
        .def("get_stream_source_id", py::overload_cast<Titta::Stream>(&TittaLSL::Sender::getStreamSourceID, py::const_),
            "stream"_a)

        // outlets
        .def("start", [](TittaLSL::Sender& instance_, std::string stream_, std::optional<bool> as_gif_) { return instance_.start(std::move(stream_), as_gif_, true); },
            "stream"_a, py::arg_v("as_gif", std::nullopt, "None"))
        .def("start", py::overload_cast<Titta::Stream, std::optional<bool>>(&TittaLSL::Sender::start),
            "stream"_a, py::arg_v("as_gif", std::nullopt, "None"))

        .def("is_streaming", [](const TittaLSL::Sender& instance_, std::string stream_) -> bool { return instance_.isStreaming(std::move(stream_), true); },
            "stream"_a)
        .def("is_streaming", py::overload_cast<Titta::Stream>(&TittaLSL::Sender::isStreaming, py::const_),
            "stream"_a)

        .def("set_include_eye_openness_in_gaze", &TittaLSL::Sender::setIncludeEyeOpennessInGaze,
            "include"_a)

        .def("stop", [](TittaLSL::Sender& instance_, std::string stream_) { instance_.stop(std::move(stream_), true); },
            "stream"_a)
        .def("stop", py::overload_cast<Titta::Stream>(&TittaLSL::Sender::stop),
            "stream"_a)
    ;

        // inlets
    auto cReceiver = py::class_<TittaLSL::Receiver>(m, "Receiver")
        .def(py::init<std::string, std::optional<size_t>, std::optional<bool>>(),
            "stream_source_ID"_a, py::arg_v("initial_buffer_size", std::nullopt, "None"), py::arg_v("start_recording", std::nullopt, "None"))

        .def("__repr__",
            [](const TittaLSL::Receiver& instance_)
            {
                return string_format("<TittaLSL.Receiver (%s)>",Titta::streamToString(instance_.getType()).c_str());
            })

        .def_static("get_streams", [](std::optional<std::string> stream_) { return StructVectorToList(TittaLSL::Receiver::GetStreams(stream_ ? *stream_ : "")); },
            py::arg_v("stream_type", std::nullopt, "None"))

        .def("get_info", [](const TittaLSL::Receiver& instance_) { return StructToDict(instance_.getInfo()); })
        .def("get_type", py::overload_cast<>(&TittaLSL::Receiver::getType, py::const_))

        .def("start", &TittaLSL::Receiver::start)

        .def("is_recording", py::overload_cast<>(&TittaLSL::Receiver::isRecording, py::const_))

        .def("consume_N",
            [](TittaLSL::Receiver& instance_, const std::optional<size_t> NSamp_, std::optional<std::variant<std::string, Titta::BufferSide>> side_)
            -> py::dict
            {
                std::optional<Titta::BufferSide> bufSide;
                if (side_.has_value())
                {
                    if (std::holds_alternative<std::string>(*side_))
                        bufSide = Titta::stringToBufferSide(std::get<std::string>(*side_));
                    else
                        bufSide = std::get<Titta::BufferSide>(*side_);
                }

                switch (instance_.getType())
                {
                case Titta::Stream::Gaze:
                case Titta::Stream::EyeOpenness:
                    return StructVectorToDict(instance_.consumeN<TittaLSL::Receiver::gaze>(NSamp_, bufSide));
                case Titta::Stream::EyeImage:
                    return StructVectorToDict(instance_.consumeN<TittaLSL::Receiver::eyeImage>(NSamp_, bufSide));
                case Titta::Stream::ExtSignal:
                    return StructVectorToDict(instance_.consumeN<TittaLSL::Receiver::extSignal>(NSamp_, bufSide));
                case Titta::Stream::TimeSync:
                    return StructVectorToDict(instance_.consumeN<TittaLSL::Receiver::timeSync>(NSamp_, bufSide));
                case Titta::Stream::Positioning:
                    return StructVectorToDict(instance_.consumeN<TittaLSL::Receiver::positioning>(NSamp_, bufSide));
                }
                return {};
            },
            py::arg_v("N_samples", std::nullopt, "None"), py::arg_v("side", std::nullopt, "None"))
        .def("consume_time_range",
            [](TittaLSL::Receiver& instance_, const std::optional<int64_t> timeStart_, const std::optional<int64_t> timeEnd_, const std::optional<bool> timeIsLocalTime_)
            -> py::dict
            {
                switch (instance_.getType())
                {
                case Titta::Stream::Gaze:
                case Titta::Stream::EyeOpenness:
                    return StructVectorToDict(instance_.consumeTimeRange<TittaLSL::Receiver::gaze>(timeStart_, timeEnd_, timeIsLocalTime_));
                case Titta::Stream::EyeImage:
                    return StructVectorToDict(instance_.consumeTimeRange<TittaLSL::Receiver::eyeImage>(timeStart_, timeEnd_, timeIsLocalTime_));
                case Titta::Stream::ExtSignal:
                    return StructVectorToDict(instance_.consumeTimeRange<TittaLSL::Receiver::extSignal>(timeStart_, timeEnd_, timeIsLocalTime_));
                case Titta::Stream::TimeSync:
                    return StructVectorToDict(instance_.consumeTimeRange<TittaLSL::Receiver::timeSync>(timeStart_, timeEnd_, timeIsLocalTime_));
                case Titta::Stream::Positioning:
                    DoExitWithMsg("TittaLSL::cpp::consume_time_range: not supported for positioning stream.");
                }
                return {};
            },
            py::arg_v("time_start", std::nullopt, "None"), py::arg_v("time_end", std::nullopt, "None"), py::arg_v("time_is_local_time", std::nullopt, "None"))

        .def("peek_N",
            [](TittaLSL::Receiver& instance_, const std::optional<size_t> NSamp_, std::optional<std::variant<std::string, Titta::BufferSide>> side_)
            -> py::dict
            {
                std::optional<Titta::BufferSide> bufSide;
                if (side_.has_value())
                {
                    if (std::holds_alternative<std::string>(*side_))
                        bufSide = Titta::stringToBufferSide(std::get<std::string>(*side_));
                    else
                        bufSide = std::get<Titta::BufferSide>(*side_);
                }

                switch (instance_.getType())
                {
                case Titta::Stream::Gaze:
                case Titta::Stream::EyeOpenness:
                    return StructVectorToDict(instance_.peekN<TittaLSL::Receiver::gaze>(NSamp_, bufSide));
                case Titta::Stream::EyeImage:
                    return StructVectorToDict(instance_.peekN<TittaLSL::Receiver::eyeImage>(NSamp_, bufSide));
                case Titta::Stream::ExtSignal:
                    return StructVectorToDict(instance_.peekN<TittaLSL::Receiver::extSignal>(NSamp_, bufSide));
                case Titta::Stream::TimeSync:
                    return StructVectorToDict(instance_.peekN<TittaLSL::Receiver::timeSync>(NSamp_, bufSide));
                case Titta::Stream::Positioning:
                    return StructVectorToDict(instance_.peekN<TittaLSL::Receiver::positioning>(NSamp_, bufSide));
                }
                return {};
            },
            py::arg_v("N_samples", std::nullopt, "None"), py::arg_v("side", std::nullopt, "None"))
        .def("peek_time_range",
            [](TittaLSL::Receiver& instance_, const std::optional<int64_t> timeStart_, const std::optional<int64_t> timeEnd_, const std::optional<bool> timeIsLocalTime_)
            -> py::dict
            {
                switch (instance_.getType())
                {
                case Titta::Stream::Gaze:
                case Titta::Stream::EyeOpenness:
                    return StructVectorToDict(instance_.peekTimeRange<TittaLSL::Receiver::gaze>(timeStart_, timeEnd_, timeIsLocalTime_));
                case Titta::Stream::EyeImage:
                    return StructVectorToDict(instance_.peekTimeRange<TittaLSL::Receiver::eyeImage>(timeStart_, timeEnd_, timeIsLocalTime_));
                case Titta::Stream::ExtSignal:
                    return StructVectorToDict(instance_.peekTimeRange<TittaLSL::Receiver::extSignal>(timeStart_, timeEnd_, timeIsLocalTime_));
                case Titta::Stream::TimeSync:
                    return StructVectorToDict(instance_.peekTimeRange<TittaLSL::Receiver::timeSync>(timeStart_, timeEnd_, timeIsLocalTime_));
                case Titta::Stream::Positioning:
                    DoExitWithMsg("Titta::cpp::peek_time_range: not supported for positioning stream.");
                }
                return {};
            },
            py::arg_v("time_start", std::nullopt, "None"), py::arg_v("time_end", std::nullopt, "None"), py::arg_v("time_is_local_time", std::nullopt, "None"))

        .def("clear", &TittaLSL::Receiver::clear)
        .def("clear_time_range", &TittaLSL::Receiver::clearTimeRange,
            py::arg_v("time_start", std::nullopt, "None"), py::arg_v("time_end", std::nullopt, "None"), py::arg_v("time_is_local_time", std::nullopt, "None"))

        .def("stop", &TittaLSL::Receiver::stop,
            py::arg_v("clear_buffer", std::nullopt, "None"))
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
