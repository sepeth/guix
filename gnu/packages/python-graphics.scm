;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2021 Adam Kandur <kefironpremise@gmail.com>
;;; Copyright © 2021 Morgan Smith <Morgan.J.Smith@outlook.com>
;;; Copyright © 2021, 2023 Daniel Meißner <daniel.meissner-i4k@ruhr-uni-bochum.de>
;;; Copyright © 2023 Adam Faiz <adam.faiz@disroot.org>
;;; Copyright © 2023 Simon Tournier <zimon.toutoune@gmail.com>
;;; Copyright © 2024 Sharlatan Hellseher <sharlatanus@gmail.com>

(define-module (gnu packages python-graphics)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module ((guix build-system python) #:select (pypi-uri))
  #:use-module (guix build-system pyproject)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module (guix packages)
  #:use-module (gnu packages)
  #:use-module (gnu packages audio)
  #:use-module (gnu packages base)
  #:use-module (gnu packages check)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages fontutils)
  #:use-module (gnu packages gl)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages maths)
  #:use-module (gnu packages pulseaudio)
  #:use-module (gnu packages python-build)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages simulation)
  #:use-module (gnu packages video)
  #:use-module (gnu packages xorg))

;;; Commentary:
;;;
;;; Python modules which are meant to be used in GUI creation or mainly are
;;; bindings to low level libraries such as Glue, Mesa, OpenGL, Xorg etc.
;;;
;;; Please: Try to add new module packages in alphabetic order.
;;;
;;; Code:

(define-public python-glcontext
  (let (;; Upstream is known for abusing mutable tag, hence pinpoint the
        ;; relevant commit.
        (revision "2")
        (commit "f2875abdb18b24e785c3958cc22845c81725d5cd"))
    (package
      (name "python-glcontext")
      (version (git-version "3.0.0" revision commit))
      (source
       (origin
         (method git-fetch)
         (uri (git-reference
               (url "https://github.com/moderngl/glcontext")
               (commit commit)))
         (file-name (git-file-name name version))
         (sha256
          (base32 "15pngnc4agdvm8crq782vjlb5v1qrclln5xpqiyhz3jhmipsqb8q"))))
      (build-system pyproject-build-system)
      (arguments
       (list
        #:phases
        #~(modify-phases %standard-phases
            (add-before 'build 'fix-lib-paths
              (lambda* (#:key inputs outputs #:allow-other-keys)
                (let ((mesa (assoc-ref inputs "mesa"))
                      (libx11 (assoc-ref inputs "libx11")))
                  (substitute* '("glcontext/x11.cpp"
                                 "glcontext/egl.cpp")
                    (("\"libGL.so\"")
                     (string-append "\"" mesa "/lib/libGL.so\""))
                    (("\"libEGL.so\"")
                     (string-append "\"" mesa "/lib/libEGL.so\""))
                    (("\"libX11.so\"")
                     (string-append "\"" libx11 "/lib/libX11.so\"")))
                  (substitute* '("glcontext/__init__.py")
                    (("find_library\\('GL'\\)")
                     (string-append "'" mesa "/lib/libGL.so'"))
                    (("find_library\\('EGL'\\)")
                     (string-append "'" mesa "/lib/libEGL.so'"))
                    (("find_library\\(\"X11\"\\)")
                     (string-append "'" libx11 "/lib/libX11.so'"))))))
            (add-before 'check 'prepare-test-environment
              (lambda _
                (system "Xvfb :1 &")
                (setenv "DISPLAY" ":1"))))))
      (inputs
       (list libx11
             mesa))
      (native-inputs
       (list python-psutil
             python-pytest
             python-setuptools
             python-wheel
             xorg-server-for-tests))
      (home-page "https://github.com/moderngl/glcontext")
      (synopsis "Portable OpenGL Context for ModernGL")
      (description
       "Python-glcontext is a library providing an OpenGL implementation for
ModernGL on multiple platforms.")
      (license license:expat))))

(define-public python-glfw
  (package
    (name "python-glfw")
    (version "2.8.0")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "glfw" version))
       (sha256
        (base32 "1w36jvn6fx8p7irhwj6bbl67m2id3s0227b3w7bgw9hbicr0vsch"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:tests? #f ; no tests provided
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'fix-lib-paths
            (lambda _
              (substitute* "glfw/library.py"
                (("_get_library_search_paths\\(\\), ")
                 (format #f "[ '~a/lib' ],"
                         #$(this-package-input "glfw")))))))))
    (native-inputs
     (list python-pytest
           python-setuptools
           python-wheel))
    (inputs
     (list glfw))
    (home-page "https://github.com/FlorianRhiem/pyGLFW")
    (synopsis "Python bindings for GLFW")
    (description
     "This package provides Python bindings for @url{http://www.glfw.org/,
GLFW} OpenGL application development library.")
    (license license:expat)))

(define-public python-pyglet
  (package
    (name "python-pyglet")
    (version "2.0.18")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "pyglet" version))
       (sha256
        (base32 "1p4rizj81vfqxal288m3afbrgk0il3w7k5kmhai2sah8f26j7ybw"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:test-flags
      #~(list "tests"
              "--ignore=tests/interactive"
              ;; All tests errored
              "--ignore=tests/integration/media/test_openal.py"
              "--ignore=tests/integration/text/test_empty_document.py"
              ;; Tests failed
              "-k" (string-append "not test2"
                                  " and not test5"
                                  " and not testPad"
                                  " and not testPad"
                                  " and not testRange"
                                  " and not testRect"
                                  " and not testRect"
                                  " and not testSet"
                                  " and not testSquare"
                                  " and not testSquare"
                                  " and not testTuple"
                                  " and not testTupleRange"
                                  " and not test_context_noshare_texture"
                                  " and not test_context_share_texture"
                                  " and not test_method"
                                  " and not test_openal_listener"
                                  " and not test_parse_all_controller_mappings"
                                  " and not test_player_play"
                                  " and not test_player_play_multiple"
                                  " and not test_stream_write_needed"
                                  " and not test_window_caption"
                                  " and not test_window_caption_from_argv"))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'patch-lib-paths
            (lambda* (#:key inputs #:allow-other-keys)
              (substitute* (list "pyglet/font/fontconfig.py"
                                 "pyglet/font/freetype_lib.py"
                                 "pyglet/gl/lib_glx.py"
                                 "pyglet/input/linux/evdev.py"
                                 "pyglet/libs/egl/egl.py"
                                 "pyglet/libs/egl/lib.py"
                                 "pyglet/libs/x11/xf86vmode.py"
                                 "pyglet/libs/x11/xinerama.py"
                                 "pyglet/libs/x11/xlib.py"
                                 "pyglet/libs/x11/xsync.py"
                                 "pyglet/media/drivers/openal/lib_openal.py"
                                 "pyglet/media/drivers/pulse/lib_pulseaudio.py")
                (("'EGL'")
                 (format #f "'~a/~a'" #$(this-package-input "mesa")
                         "lib/libEGL.so"))
                (("\"fontconfig\"")
                 (format #f "'~a/~a'" #$(this-package-input "fontconfig-minimal")
                         "lib/libfontconfig.so"))
                (("\"freetype\"")
                 (format #f "'~a/~a'" #$(this-package-input "freetype")
                         "lib/libfreetype.so"))
                (("'GL'")
                 (format #f "'~a/~a'" #$(this-package-input "mesa")
                         "lib/libGL.so"))
                (("'GLU'")
                 (format #f "'~a/~a'" #$(this-package-input "glu")
                         "lib/libGLU.so"))
                (("'X11'")
                 (format #f "'~a/~a'" #$(this-package-input "libx11")
                         "lib/libX11.so"))
                (("'Xext'")
                 (format #f "'~a/~a'" #$(this-package-input "libxext")
                         "lib/libXext.so"))
                (("'Xinerama'")
                 (format #f "'~a/~a'" #$(this-package-input "libxinerama")
                         "lib/libXinerama.so"))
                (("'Xxf86vm'")
                 (format #f "'~a/~a'" #$(this-package-input "libxxf86vm")
                         "lib/libXxf86vm.so"))
                (("'c'")
                 (format #f "'~a/~a'" #$(this-package-input "glibc")
                         "lib/libc.so"))
                (("'gdk-x11-2.0'")
                 (format #f "'~a/~a'" #$(this-package-input "gtk+")
                         "lib/gdk-pixbuf-2.0.so"))
                (("'gdk_pixbuf-2.0'")
                 (format #f "'~a/~a'" #$(this-package-input "gdk-pixbuf")
                         "lib/libgdk_pixbuf-2.0.so"))
                (("'openal'")
                 (format #f "'~a/~a'" #$(this-package-input "openal")
                         "lib/libopenal.so"))
                (("'pulse'")
                 (format #f "'~a/~a'" #$(this-package-input "pulseaudio")
                         "lib/libpulse.so")))))
          (add-before 'check 'prepare-test-environment
            (lambda _
              ;; The test suite requires a running X server.
              (system "Xvfb :1 &")
              (setenv "DISPLAY" ":1")
              (setenv "HOME" "/tmp")
              (setenv "PYGLET_HEADLESS" "True"))))))
    (native-inputs
     (list python-flit-core
           python-pytest
           unzip
           xorg-server-for-tests))
    (inputs
     (list ffmpeg
           fontconfig
           freeglut
           freetype
           gdk-pixbuf
           glibc
           glu
           gtk+
           libx11
           libxext
           libxinerama
           libxxf86vm
           mesa
           openal
           pulseaudio))
    (home-page "https://github.com/pyglet/pyglet")
    (synopsis "Windowing and multimedia library")
    (description
     "Pyglet is a Python library for developing games and other visually-rich
applications.  It supports windowing, user interface event handling,
Joysticks, OpenGL graphics, loading images and videos, playing sounds and
music." )
    (license license:bsd-3)))

(define-public python-vispy
  (package
    (name "python-vispy")
    (version "0.14.3")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "vispy" version))
       (sha256
        (base32 "07fkk4bdffn0iq5cprk7ydj978rqc4lvzfcs2vkzgfh8m53vifzg"))))
    (build-system pyproject-build-system)
    (arguments
     (list
      #:test-flags
      ;; Test requiring network access to download test data from
      ;; <https://raw.githubusercontent.com/vispy/demo-data/main/CONTRIBUTING.txt>.
      #~(list "-k" (string-append "not test_read_write_image"
                                  " and not test_wavefront"
                                  " and not test_config"))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'patch-library-path
            (lambda _
              (substitute* (list "vispy/ext/egl.py"
                                 "vispy/ext/fontconfig.py"
                                 "vispy/gloo/gl/es2.py"
                                 "vispy/gloo/gl/gl2.py")
                (("ctypes\\.util\\.find_library\\('EGL'\\)")
                 (format #f "'~a/~a'" #$(this-package-input "mesa")
                         "lib/libEGL.so"))
                (("ctypes\\.util\\.find_library\\('GL'\\)")
                 (format #f "'~a/~a'" #$(this-package-input "mesa")
                         "lib/libGL.so"))
                (("ctypes\\.util\\.find_library\\('GLESv2'\\)")
                 (format #f "'~a/~a'" #$(this-package-input "mesa")
                         "lib/libGLESv2.so"))
                (("util\\.find_library\\('fontconfig'\\)")
                 (format #f "'~a/~a'" #$(this-package-input "fontconfig-minimal")
                         "lib/libfontconfig.so")))))
          (add-before 'check 'prepare-test-environment
            (lambda _
              ;; XXX: Check how to set DPI to run headless tests, fails when
              ;; DISPLAY is set.
              ;; E RuntimeError: could not determine DPI
              (setenv "HOME" "/tmp")
              (invoke "python" "setup.py" "build_ext" "--inplace"))))))
    (native-inputs
     (list python-cython-3
           python-pytest
           python-setuptools
           python-setuptools-scm
           python-wheel))
    (inputs
     (list fontconfig
           mesa))
    (propagated-inputs
     (list python-freetype-py
           python-hsluv
           python-kiwisolver
           python-meshio
           python-numpy
           python-packaging
           python-pillow))
    (home-page "http://vispy.org")
    (synopsis "Interactive scientific visualization in Python")
    (description
     "VisPy is a high-performance interactive 2D/3D data visualization library
leveraging the computational power of modern Graphics Processing Units (GPUs)
through the OpenGL library to display very large datasets.")
    (license license:bsd-3)))

;;;
;;; Avoid adding new packages to the end of this file. To reduce the chances
;;; of a merge conflict, place them above in alphabetical order.
;;;
