#include "TobiiMex/TobiiMex.h"
#include "TobiiMex/utils.h"

#include <iostream>
#include <string>
#include <memory>
#include <variant>
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

template <typename T> std::string toString(const T& instance_, std::string spacing="");

template <> std::string toString<>(const TobiiTypes::eyeImage& instance_, std::string spacing)
{
    return string_format("%s image from camera %d, %dbit, %dx%d", imageType(instance_.type), instance_.camera_id, instance_.bits_per_pixel, instance_.width, instance_.height);
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
        .def_property_readonly("image",&imageToNumpy)
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

    py::class_<TobiiMex>(m, "wrapper")
        .def(py::init<std::string>(),"address"_a)

        .def("__repr__",
            [](TobiiMex& instance_)
            {
                return string_format("<TobiiWrapper.wrapper connected to '%s' @%.0f Hz at '%s'>", instance_.getConnectedEyeTracker().model.c_str(), instance_.getCurrentFrequency(), instance_.getConnectedEyeTracker().address.c_str());
            })

        .def("start", py::overload_cast<std::string, std::optional<size_t>, std::optional<bool>>(&TobiiMex::start),
            "stream"_a, py::arg_v("initialBufferSize", std::nullopt, "None"), py::arg_v("asGif", std::nullopt, "None"))

        .def("peekN",
            [](TobiiMex& instance_, std::string stream_, std::optional<size_t> NSamp_, std::string side_)
            -> std::variant<std::vector<TobiiMex::gaze>, std::vector<TobiiMex::eyeImage>>
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
                }
            },
            "stream"_a, py::arg_v("NSamp", std::nullopt, "None"), "side"_a = "")

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