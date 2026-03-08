#!/usr/bin/env bash
#
# @intent Pandoc/media toolchain module (pandoc, ffmpeg, yt-dlp, faster-whisper).
# @complexity 2
#

TOOL_APPARMOR_RULES[pandoc]=$(cat <<'RULES'
  # ── Document processing tools ───────────────────────────────────────────────
  # pandoc: CLI for md↔docx/pptx/pdf conversions
  /usr/bin/pandoc                      ix,
  # xelatex / pdflatex: PDF engine called by pandoc
  /usr/bin/xelatex                     ix,
  /usr/bin/pdflatex                    ix,
  /usr/bin/xdvipdfmx                   ix,
  /usr/share/texlive/**                r,
  /usr/share/texmf/**                  r,
  /var/lib/texmf/**                    r,
  @{HOME}/.texlive*/                   rw,
  @{HOME}/.texlive*/**                 rw,
  # poppler: pdftotext / pdftoppm (PDF read + image extraction)
  /usr/bin/pdftotext                   ix,
  /usr/bin/pdftoppm                    ix,
  /usr/lib/x86_64-linux-gnu/libpoppler* mr,
  # pandoc scratch space
  /tmp/pandoc-*/                       rw,
  /tmp/pandoc-*/**                     rw,

  # ── Media download tools ─────────────────────────────────────────────────────
  # yt-dlp is a Python script — needs rix (read + inherit + execute), not just ix.
  # Without r, AppArmor denies the open() the kernel does to read the script.
  # ffmpeg/ffprobe are ELF binaries called by yt-dlp for muxing/extraction.
  # dist-packages: yt-dlp imports from /usr/local/lib/python3.x/dist-packages/
  # (covered by the python3 block above, but listed explicitly to be unambiguous).
  @{HOME}/.local/bin/**                mrix,
  @{HOME}/.local/bin/yt-dlp            rix,
  /usr/local/bin/yt-dlp                rix,
  /usr/bin/yt-dlp                      rix,
  /usr/bin/ffmpeg                      rix,
  /usr/bin/ffprobe                     rix,
  # faster-whisper / CTranslate2 — speech-to-text
  # ct2 is a C++ extension that mmap()s model weights and uses AVX intrinsics
  /usr/local/lib/python3*/dist-packages/ctranslate2/**  mr,
  /usr/local/lib/python3*/dist-packages/faster_whisper/**  r,
  /tmp/whisper-*/                      rwk,
  /tmp/whisper-/**                     rwk,
  # HuggingFace model cache — faster-whisper downloads model weights here
  # Needs 'k' for filelock advisory locks used during concurrent model downloads
  # rw = download + write model files; m = mmap model weights (CTranslate2)
  @{HOME}/.cache/huggingface/          rwk,
  @{HOME}/.cache/huggingface/**        mrwk,
  # faster-whisper uses /tmp for intermediate audio chunks
  # /tmp/** needs k so filelock can flock() arbitrary lock files
  /tmp/                                rwk,
  /tmp/**                              rwk,
  # Python packages — /usr/local for pip-installed, /usr/lib for apt-installed
  /usr/local/lib/python3*/dist-packages/      r,
  /usr/local/lib/python3*/dist-packages/**    r,
  # Ubuntu system Python packages (lxml, openpyxl apt path)
  /usr/lib/python3/dist-packages/             r,
  /usr/lib/python3/dist-packages/**           r,
  /usr/lib/python3*/dist-packages/            r,
  /usr/lib/python3*/dist-packages/**          r,
  # lxml C-extension .so files — pip-installed lxml bundles its own libxml2/xslt
  # Need mr (map+read) at every path level since pip and apt use different locations
  /usr/lib/python3*/dist-packages/lxml/*.cpython-*.so   mr,
  /usr/lib/python3*/dist-packages/lxml/**               mr,
  /usr/local/lib/python3*/dist-packages/lxml/**         mr,
  /usr/local/lib/python3*/dist-packages/**/*.so         mr,
  /usr/local/lib/python3*/dist-packages/**/*.cpython-*.so mr,
  # libexslt — lxml links against this for XSLT extension functions
  /usr/lib/x86_64-linux-gnu/libexslt*         mr,
  # PyAV (av module) — faster-whisper uses this for audio decoding
  # PyAV wraps libavcodec/libavformat/libswresample/libswscale directly
  /usr/local/lib/python3*/dist-packages/av/**           mr,
  /usr/lib/x86_64-linux-gnu/libavcodec*        mr,
  /usr/lib/x86_64-linux-gnu/libavformat*       mr,
  /usr/lib/x86_64-linux-gnu/libavutil*         mr,
  /usr/lib/x86_64-linux-gnu/libswresample*     mr,
  /usr/lib/x86_64-linux-gnu/libswscale*        mr,
  /usr/lib/x86_64-linux-gnu/libavfilter*       mr,
  /usr/lib/x86_64-linux-gnu/libavdevice*       mr,
  # libva (hardware accel stubs — present on system even if no GPU, av imports check for it)
  /usr/lib/x86_64-linux-gnu/libva*             mr,
  /usr/lib/x86_64-linux-gnu/libdrm*            mr,
  # openpyxl reads /etc/mime.types to determine content-type for xlsx
  /etc/mime.types                             r,
  # ctranslate2 and Python platform module read these for system/package info
  /etc/default/apport                         r,
  /etc/apt/apt.conf.d/                        r,
  /etc/apt/apt.conf.d/**                      r,
  /usr/share/dpkg/cputable                    r,
  /usr/share/dpkg/tupletable                  r,
  /usr/share/dpkg/ostable                     r,
  /etc/mime.types.d/                          r,
  /etc/mime.types.d/**                        r,
  # libxml2 / libxslt shared libs used by lxml + python-docx
  /usr/lib/x86_64-linux-gnu/libxml2*          mr,
  /usr/lib/x86_64-linux-gnu/libxslt*          mr,
  /usr/lib/x86_64-linux-gnu/libz*             mr,
  # PIL/Pillow — python-docx uses it for image handling in .docx files
  /usr/local/lib/python3*/dist-packages/PIL/**            mr,
  /usr/local/lib/python3*/dist-packages/Pillow*/          r,
  /usr/lib/x86_64-linux-gnu/libjpeg*          mr,
  /usr/lib/x86_64-linux-gnu/libpng*           mr,
  /usr/lib/x86_64-linux-gnu/libtiff*          mr,
  /usr/lib/x86_64-linux-gnu/libwebp*          mr,
  /usr/lib/x86_64-linux-gnu/libopenjp2*       mr,
  # numpy C extensions — used by faster-whisper, openpyxl, many others
  /usr/local/lib/python3*/dist-packages/numpy/**          mr,
  /usr/local/lib/python3*/dist-packages/numpy/core/**     mr,
  # CTranslate2 — faster-whisper's C++ inference engine
  # Links against OpenBLAS (BLAS/LAPACK) and OpenMP for multi-threaded compute
  /usr/lib/x86_64-linux-gnu/libopenblas*      mr,
  /usr/lib/x86_64-linux-gnu/libblas*          mr,
  /usr/lib/x86_64-linux-gnu/liblapack*        mr,
  /usr/lib/x86_64-linux-gnu/libgomp*          mr,
  /usr/lib/x86_64-linux-gnu/libomp*           mr,
  /usr/lib/x86_64-linux-gnu/libgfortran*      mr,
  /usr/lib/x86_64-linux-gnu/libstdc++*        mr,
  /usr/lib/x86_64-linux-gnu/libgcc_s*         mr,
  /usr/lib/x86_64-linux-gnu/libquadmath*      mr,
  # OpenMP thread spawning reads these
  /sys/devices/system/cpu/                    r,
  /sys/devices/system/cpu/**                  r,
  # sqlite3 CLI — used directly by memory-management skill
  /usr/bin/sqlite3                            ix,
  # sqlite3 shared library — used by Python sqlite3 module
  /usr/lib/x86_64-linux-gnu/libsqlite3*       mr,
RULES
)

TOOL_ENV_PLACEHOLDERS[pandoc]=""
TOOL_SYSTEMD_EXPORTS[pandoc]=""

# ── 7b. INSTALL PYTHON PACKAGES ───────────────────────────────────────────────
install_pandoc() {
    log "Installing pandoc, PDF engine, and ffmpeg..."
    local pkgs=(pandoc texlive-xetex poppler-utils ffmpeg sqlite3)
    local missing=()
    local p
    for p in "${pkgs[@]}"; do
        dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p")
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        log "pandoc/ffmpeg toolchain already installed."
    else
        wait_for_apt
        apt_install "${missing[@]}" \
            && log "pandoc toolchain installed." \
            || log "WARNING: pandoc install failed."
    fi

    log "Installing Python packages for agent use..."
    local pip_packages=(
        pytest pytest-asyncio requests python-dotenv rich yt-dlp
        python-docx openpyxl python-pptx markitdown
        faster-whisper av markdown pyyaml
    )
    local pkg
    for pkg in "${pip_packages[@]}"; do
        uas python3 -m pip install --user --quiet --break-system-packages "$pkg" \
            && log "  pip: installed $pkg" \
            || log "  WARNING: pip install $pkg failed."
    done
}

register_tool pandoc
