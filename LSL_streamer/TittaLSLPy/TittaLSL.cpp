#define _CRT_SECURE_NO_WARNINGS
#include "Titta/Titta.h"
#include "Titta/utils.h"
#include "LSL_streamer/LSL_streamer.h"

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




template<typename ... Args>
std::string string_format(const std::string& format, Args ... args)
{
    auto size = static_cast<size_t>(snprintf(nullptr, 0, format.c_str(), args ...)) + 1; // Extra space for '\0'
    std::unique_ptr<char[]> buf(new char[size]);
    snprintf(buf.get(), size, format.c_str(), args ...);
    return std::string(buf.get(), buf.get() + size - 1); // We don't want the '\0' inside
}


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

void FieldToNpArray(py::dict& out_, const std::vector<LSL_streamer::gaze>& data_, const std::string& name_, TobiiTypes::eyeData Titta::gaze::* field_)
{
    // 1. gaze_point
    auto localName = name_ + "_gaze_point_";
    // 1.1 gaze_point_on_display_area
    TobiiFieldToNpArray (out_, data_, localName+"on_display_area"    , &LSL_streamer::gaze::gazeData, field_, &TobiiTypes::eyeData::gaze_point, &TobiiTypes::gazePoint::position_on_display_area);
    // 1.2 gaze_point_in_user_coordinates
    TobiiFieldToNpArray (out_, data_, localName+"in_user_coordinates", &LSL_streamer::gaze::gazeData, field_, &TobiiTypes::eyeData::gaze_point, &TobiiTypes::gazePoint::position_in_user_coordinates);
    // 1.3 gaze_point_valid
    FieldToNpArray<true>(out_, data_, localName+"valid"              , &LSL_streamer::gaze::gazeData, field_, &TobiiTypes::eyeData::gaze_point, &TobiiTypes::gazePoint::validity, TOBII_RESEARCH_VALIDITY_VALID);
    // 1.4 gaze_point_available
    FieldToNpArray<true>(out_, data_, localName+"available"          , &LSL_streamer::gaze::gazeData, field_, &TobiiTypes::eyeData::gaze_point, &TobiiTypes::gazePoint::available);

    // 2. pupil
    localName = name_ + "_pupil_";
    // 2.1 pupil_diameter
    FieldToNpArray<true>(out_, data_, localName + "diameter" , &LSL_streamer::gaze::gazeData, field_, &TobiiTypes::eyeData::pupil, &TobiiTypes::pupilData::diameter);
    // 2.2 pupil_valid
    FieldToNpArray<true>(out_, data_, localName + "valid"    , &LSL_streamer::gaze::gazeData, field_, &TobiiTypes::eyeData::pupil, &TobiiTypes::pupilData::validity, TOBII_RESEARCH_VALIDITY_VALID);
    // 2.3 pupil_available
    FieldToNpArray<true>(out_, data_, localName + "available", &LSL_streamer::gaze::gazeData, field_, &TobiiTypes::eyeData::pupil, &TobiiTypes::pupilData::available);

    // 3. gazeOrigin
    localName = name_ + "_gaze_origin_";
    // 3.1 gaze_origin_in_user_coordinates
    TobiiFieldToNpArray (out_, data_, localName + "in_user_coordinates"     , &LSL_streamer::gaze::gazeData, field_, &TobiiTypes::eyeData::gaze_origin, &TobiiTypes::gazeOrigin::position_in_user_coordinates);
    // 3.2 gaze_origin_in_track_box_coordinates
    TobiiFieldToNpArray (out_, data_, localName + "in_track_box_coordinates", &LSL_streamer::gaze::gazeData, field_, &TobiiTypes::eyeData::gaze_origin, &TobiiTypes::gazeOrigin::position_in_track_box_coordinates);
    // 3.3 gaze_origin_valid
    FieldToNpArray<true>(out_, data_, localName + "valid"                   , &LSL_streamer::gaze::gazeData, field_, &TobiiTypes::eyeData::gaze_origin, &TobiiTypes::gazeOrigin::validity, TOBII_RESEARCH_VALIDITY_VALID);
    // 3.4 gaze_origin_available
    FieldToNpArray<true>(out_, data_, localName + "available"               , &LSL_streamer::gaze::gazeData, field_, &TobiiTypes::eyeData::gaze_origin, &TobiiTypes::gazeOrigin::available);

    // 4. eyeOpenness
    localName = name_ + "_eye_openness_";
    // 4.1 eye_openness_diameter
    FieldToNpArray<true>(out_, data_, localName + "diameter"  , &LSL_streamer::gaze::gazeData, field_, &TobiiTypes::eyeData::eye_openness, &TobiiTypes::eyeOpenness::diameter);
    // 4.2 eye_openness_valid
    FieldToNpArray<true>(out_, data_, localName + "valid"     , &LSL_streamer::gaze::gazeData, field_, &TobiiTypes::eyeData::eye_openness, &TobiiTypes::eyeOpenness::validity, TOBII_RESEARCH_VALIDITY_VALID);
    // 4.3 eye_openness_available
    FieldToNpArray<true>(out_, data_, localName + "available" , &LSL_streamer::gaze::gazeData, field_, &TobiiTypes::eyeData::eye_openness, &TobiiTypes::eyeOpenness::available);
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
void outputEyeImages(py::dict& out_, const std::vector<LSL_streamer::eyeImage>& data_, const std::string& name_)
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



py::dict StructVectorToDict(std::vector<LSL_streamer::gaze> data_)
{
    py::dict out;

    // 1. remote system timestamps
    FieldToNpArray<true>(out, data_, "remote_system_time_stamp", &LSL_streamer::gaze::remote_system_time_stamp);
    // 2. local system timestamps
    FieldToNpArray<true>(out, data_, "local_system_time_stamp" , &LSL_streamer::gaze::local_system_time_stamp);
    // 3. device timestamps
    FieldToNpArray<true>(out, data_, "device_time_stamp", &LSL_streamer::gaze::gazeData, &Titta::gaze::device_time_stamp);
    // 4. system timestamps
    FieldToNpArray<true>(out, data_, "system_time_stamp", &LSL_streamer::gaze::gazeData, &Titta::gaze::system_time_stamp);
    // 5. left  eye data
    FieldToNpArray(out, data_, "left" , &Titta::gaze::left_eye);
    // 6. right eye data
    FieldToNpArray(out, data_, "right", &Titta::gaze::right_eye);

    return out;
}

py::dict StructVectorToDict(std::vector<LSL_streamer::eyeImage> data_)
{
    py::dict out;

    // check if all gif, then don't output unneeded fields
    bool allGif = allEquals(data_, &LSL_streamer::eyeImage::eyeImageData, &Titta::eyeImage::is_gif, true);

    FieldToNpArray<true>(out, data_, "remote_system_time_stamp" , &LSL_streamer::eyeImage::remote_system_time_stamp);
    FieldToNpArray<true>(out, data_, "local_system_time_stamp"  , &LSL_streamer::eyeImage::local_system_time_stamp);
    FieldToNpArray<true>(out, data_, "device_time_stamp", &LSL_streamer::eyeImage::eyeImageData, &Titta::eyeImage::device_time_stamp);
    FieldToNpArray<true>(out, data_, "system_time_stamp", &LSL_streamer::eyeImage::eyeImageData, &Titta::eyeImage::system_time_stamp);
    FieldToNpArray<true>(out, data_, "region_id"        , &LSL_streamer::eyeImage::eyeImageData, &Titta::eyeImage::region_id);
    FieldToNpArray<true>(out, data_, "region_top"       , &LSL_streamer::eyeImage::eyeImageData, &Titta::eyeImage::region_top);
    FieldToNpArray<true>(out, data_, "region_left"      , &LSL_streamer::eyeImage::eyeImageData, &Titta::eyeImage::region_left);
    if (!allGif)
    {
        FieldToNpArray<true>(out, data_, "bits_per_pixel"   , &LSL_streamer::eyeImage::eyeImageData, &Titta::eyeImage::bits_per_pixel);
        FieldToNpArray<true>(out, data_, "padding_per_pixel", &LSL_streamer::eyeImage::eyeImageData, &Titta::eyeImage::padding_per_pixel);
    }
    FieldToNpArray<false>(out, data_, "type"     , &LSL_streamer::eyeImage::eyeImageData, &Titta::eyeImage::type);
    FieldToNpArray<true> (out, data_, "camera_id", &LSL_streamer::eyeImage::eyeImageData, &Titta::eyeImage::camera_id);
    FieldToNpArray<true> (out, data_, "is_gif"   , &LSL_streamer::eyeImage::eyeImageData, &Titta::eyeImage::is_gif);
    outputEyeImages(out, data_, "image");

    return out;
}

py::dict StructVectorToDict(std::vector<LSL_streamer::extSignal> data_)
{
    py::dict out;

    FieldToNpArray<true>(out, data_, "remote_system_time_stamp", &LSL_streamer::extSignal::remote_system_time_stamp);
    FieldToNpArray<true>(out, data_, "local_system_time_stamp" , &LSL_streamer::extSignal::local_system_time_stamp);
    FieldToNpArray<true>(out, data_, "device_time_stamp", &LSL_streamer::extSignal::extSignalData, &Titta::extSignal::device_time_stamp);
    FieldToNpArray<true>(out, data_, "system_time_stamp", &LSL_streamer::extSignal::extSignalData, &Titta::extSignal::system_time_stamp);
    FieldToNpArray<true>(out, data_, "value"            , &LSL_streamer::extSignal::extSignalData, &Titta::extSignal::value);
    FieldToNpArray<false>(out, data_, "change_type"     , &LSL_streamer::extSignal::extSignalData, &Titta::extSignal::change_type);

    return out;
}

py::dict StructVectorToDict(std::vector<LSL_streamer::timeSync> data_)
{
    py::dict out;

    FieldToNpArray<true>(out, data_, "remote_system_time_stamp", &LSL_streamer::timeSync::remote_system_time_stamp);
    FieldToNpArray<true>(out, data_, "local_system_time_stamp" , &LSL_streamer::timeSync::local_system_time_stamp);
    FieldToNpArray<true>(out, data_, "system_request_time_stamp" , &LSL_streamer::timeSync::timeSyncData, &Titta::timeSync::system_request_time_stamp);
    FieldToNpArray<true>(out, data_, "device_time_stamp"         , &LSL_streamer::timeSync::timeSyncData, &Titta::timeSync::device_time_stamp);
    FieldToNpArray<true>(out, data_, "system_response_time_stamp", &LSL_streamer::timeSync::timeSyncData, &Titta::timeSync::system_response_time_stamp);

    return out;
}

py::dict StructVectorToDict(std::vector<LSL_streamer::positioning> data_)
{
    py::dict out;

    FieldToNpArray<true>(out, data_, "remote_system_time_stamp" , &LSL_streamer::positioning::remote_system_time_stamp);
    FieldToNpArray<true>(out, data_, "local_system_time_stamp"  , &LSL_streamer::positioning::local_system_time_stamp);
    TobiiFieldToNpArray(out, data_, "left_user_position"        , &LSL_streamer::positioning::positioningData, &Titta::positioning::left_eye, &TobiiResearchEyeUserPositionGuide::user_position);
    FieldToNpArray<true>(out, data_, "left_user_position_valid" , &LSL_streamer::positioning::positioningData, &Titta::positioning::left_eye , &TobiiResearchEyeUserPositionGuide::validity, TOBII_RESEARCH_VALIDITY_VALID);
    TobiiFieldToNpArray(out, data_, "right_user_position"       , &LSL_streamer::positioning::positioningData, &Titta::positioning::right_eye, &TobiiResearchEyeUserPositionGuide::user_position);
    FieldToNpArray<true>(out, data_, "right_user_position_valid", &LSL_streamer::positioning::positioningData, &Titta::positioning::right_eye, &TobiiResearchEyeUserPositionGuide::validity, TOBII_RESEARCH_VALIDITY_VALID);

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

py::list StructVectorToList(const std::vector<lsl::stream_info>& data_)
{
    py::list out;

    for (auto&& i : data_)
        out.append(StructToDict(i));

    return out;
}



// start module scope
#ifdef NDEBUG
#   define MODULE_NAME TittaLSL
#else
#   define MODULE_NAME TittaLSL_d
#endif
PYBIND11_MODULE(MODULE_NAME, m)
{
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
    m.def("get_Tobii_SDK_version", []() { const auto v = LSL_streamer::getTobiiSDKVersion(); return string_format("%d.%d.%d.%d", v.major, v.minor, v.revision, v.build); });
    m.def("get_LSL_version", &LSL_streamer::getLSLVersion);
    m.def("get_remote_streams", [](std::optional<std::string> stream_) { return StructVectorToList(LSL_streamer::getRemoteStreams(stream_ ? *stream_ : "")); },
        py::arg_v("stream_type", std::nullopt, "None"));

    // outlets
    auto cLSL = py::class_<LSL_streamer>(m, "LSLStreamer")
        .def(py::init<>())
        .def(py::init<std::string>(), "address"_a)

        // outlets
        .def("connect", py::overload_cast<std::string>(&LSL_streamer::connect),
            "address"_a)

        .def("start_outlet", [](LSL_streamer& instance, std::string stream_, std::optional<bool> as_gif_) { return instance.startOutlet(std::move(stream_), as_gif_, true); },
            "stream"_a, py::arg_v("as_gif", std::nullopt, "None"))
        .def("start", py::overload_cast<Titta::Stream, std::optional<bool>>(&LSL_streamer::startOutlet),
            "stream"_a, py::arg_v("as_gif", std::nullopt, "None"))

        .def("is_streaming", [](const LSL_streamer& instance, std::string stream_) -> bool { return instance.isStreaming(std::move(stream_), true); },
            "stream"_a)
        .def("is_streaming", py::overload_cast<Titta::Stream>(&LSL_streamer::isStreaming, py::const_),
            "stream"_a)

        .def("set_include_eye_openness_in_gaze", &LSL_streamer::setIncludeEyeOpennessInGaze,
            "include"_a)

        .def("stop_outlet", [](LSL_streamer& instance, std::string stream_) { instance.stopOutlet(std::move(stream_), true); },
            "stream"_a)
        .def("stop_outlet", py::overload_cast<Titta::Stream>(&LSL_streamer::stopOutlet),
            "stream"_a)

        // inlets
        .def("create_listener", py::overload_cast<std::string, std::optional<size_t>, std::optional<bool>>(&LSL_streamer::createListener),
            "stream_source_ID"_a, py::arg_v("initial_buffer_size", std::nullopt, "None"), py::arg_v("start_listening", std::nullopt, "None"))

        .def("get_inlet_info", [](const LSL_streamer& instance, uint32_t id_) { return StructToDict(instance.getInletInfo(id_)); },
            "inlet_id"_a)
        .def("get_inlet_type", py::overload_cast<uint32_t>(&LSL_streamer::getInletType, py::const_),
            "inlet_id"_a)

        .def("start_listening", &LSL_streamer::startListening,
            "inlet_id"_a)

        .def("is_listening", py::overload_cast<uint32_t>(&LSL_streamer::isListening, py::const_),
            "inlet_id"_a)

        .def("consume_N",
            [](LSL_streamer& instance_, uint32_t id_, std::optional<size_t> NSamp_, std::optional<std::variant<std::string, Titta::BufferSide>> side_)
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

                switch (instance_.getInletType(id_))
                {
                case Titta::Stream::Gaze:
                case Titta::Stream::EyeOpenness:
                    return StructVectorToDict(instance_.consumeN<LSL_streamer::gaze>(id_, NSamp_, bufSide));
                case Titta::Stream::EyeImage:
                    return StructVectorToDict(instance_.consumeN<LSL_streamer::eyeImage>(id_, NSamp_, bufSide));
                case Titta::Stream::ExtSignal:
                    return StructVectorToDict(instance_.consumeN<LSL_streamer::extSignal>(id_, NSamp_, bufSide));
                case Titta::Stream::TimeSync:
                    return StructVectorToDict(instance_.consumeN<LSL_streamer::timeSync>(id_, NSamp_, bufSide));
                case Titta::Stream::Positioning:
                    return StructVectorToDict(instance_.consumeN<LSL_streamer::positioning>(id_, NSamp_, bufSide));
                }
                return {};
            },
            "inlet_id"_a, py::arg_v("N_samples", std::nullopt, "None"), py::arg_v("side", std::nullopt, "None"))
        .def("consume_time_range",
            [](LSL_streamer& instance_, uint32_t id_, std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_, std::optional<bool> timeIsLocalTime_)
            -> py::dict
            {
                switch (instance_.getInletType(id_))
                {
                case Titta::Stream::Gaze:
                case Titta::Stream::EyeOpenness:
                    return StructVectorToDict(instance_.consumeTimeRange<LSL_streamer::gaze>(id_, timeStart_, timeEnd_, timeIsLocalTime_));
                case Titta::Stream::EyeImage:
                    return StructVectorToDict(instance_.consumeTimeRange<LSL_streamer::eyeImage>(id_, timeStart_, timeEnd_, timeIsLocalTime_));
                case Titta::Stream::ExtSignal:
                    return StructVectorToDict(instance_.consumeTimeRange<LSL_streamer::extSignal>(id_, timeStart_, timeEnd_, timeIsLocalTime_));
                case Titta::Stream::TimeSync:
                    return StructVectorToDict(instance_.consumeTimeRange<LSL_streamer::timeSync>(id_, timeStart_, timeEnd_, timeIsLocalTime_));
                case Titta::Stream::Positioning:
                    DoExitWithMsg("TittaLSL::cpp::consume_time_range: not supported for positioning stream.");
                }
                return {};
            },
            "stream"_a, py::arg_v("time_start", std::nullopt, "None"), py::arg_v("time_end", std::nullopt, "None"), py::arg_v("time_is_local_time", std::nullopt, "None"))

        .def("peek_N",
            [](LSL_streamer& instance_, uint32_t id_, std::optional<size_t> NSamp_, std::optional<std::variant<std::string, Titta::BufferSide>> side_)
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

                switch (instance_.getInletType(id_))
                {
                case Titta::Stream::Gaze:
                case Titta::Stream::EyeOpenness:
                    return StructVectorToDict(instance_.peekN<LSL_streamer::gaze>(id_, NSamp_, bufSide));
                case Titta::Stream::EyeImage:
                    return StructVectorToDict(instance_.peekN<LSL_streamer::eyeImage>(id_, NSamp_, bufSide));
                case Titta::Stream::ExtSignal:
                    return StructVectorToDict(instance_.peekN<LSL_streamer::extSignal>(id_, NSamp_, bufSide));
                case Titta::Stream::TimeSync:
                    return StructVectorToDict(instance_.peekN<LSL_streamer::timeSync>(id_, NSamp_, bufSide));
                case Titta::Stream::Positioning:
                    return StructVectorToDict(instance_.peekN<LSL_streamer::positioning>(id_, NSamp_, bufSide));
                }
                return {};
            },
            "stream"_a, py::arg_v("N_samples", std::nullopt, "None"), py::arg_v("side", std::nullopt, "None"))
        .def("peek_time_range",
            [](LSL_streamer& instance_, uint32_t id_, std::optional<int64_t> timeStart_, std::optional<int64_t> timeEnd_, std::optional<bool> timeIsLocalTime_)
            -> py::dict
            {
                switch (instance_.getInletType(id_))
                {
                case Titta::Stream::Gaze:
                case Titta::Stream::EyeOpenness:
                    return StructVectorToDict(instance_.peekTimeRange<LSL_streamer::gaze>(id_, timeStart_, timeEnd_, timeIsLocalTime_));
                case Titta::Stream::EyeImage:
                    return StructVectorToDict(instance_.peekTimeRange<LSL_streamer::eyeImage>(id_, timeStart_, timeEnd_, timeIsLocalTime_));
                case Titta::Stream::ExtSignal:
                    return StructVectorToDict(instance_.peekTimeRange<LSL_streamer::extSignal>(id_, timeStart_, timeEnd_, timeIsLocalTime_));
                case Titta::Stream::TimeSync:
                    return StructVectorToDict(instance_.peekTimeRange<LSL_streamer::timeSync>(id_, timeStart_, timeEnd_, timeIsLocalTime_));
                case Titta::Stream::Positioning:
                    DoExitWithMsg("Titta::cpp::peek_time_range: not supported for positioning stream.");
                }
                return {};
            },
            "stream"_a, py::arg_v("time_start", std::nullopt, "None"), py::arg_v("time_end", std::nullopt, "None"), py::arg_v("time_is_local_time", std::nullopt, "None"))

        .def("clear", &LSL_streamer::clear,
            "inlet_id"_a)
        .def("clear_time_range", &LSL_streamer::clearTimeRange,
            "inlet_id"_a, py::arg_v("time_start", std::nullopt, "None"), py::arg_v("time_end", std::nullopt, "None"), py::arg_v("time_is_local_time", std::nullopt, "None"))

        .def("stop_listening", &LSL_streamer::stopListening,
            "inlet_id"_a, py::arg_v("clear_buffer", std::nullopt, "None"))
        .def("delete_listener", &LSL_streamer::deleteListener,
            "inlet_id"_a)
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
