project(
  'some',
  'cpp',
  version: '0.1.0',
  default_options: ['cpp_std=c++20', 'warning_level=2']
)

gtkmm_dep = dependency('gtkmm-4.0', required: true)

src_scan = run_command(
  'find',
  'src',
  '-type',
  'f',
  '(',
  '-name',
  '*.cpp',
  '-o',
  '-name',
  '*.cc',
  '-o',
  '-name',
  '*.cxx',
  ')',
  check: true,
)

src_files_raw = src_scan.stdout().strip()
if src_files_raw == ''
  error('No C++ source files found in src/')
endif

src_files = src_files_raw.split('\n')

executable(
  'some-app',
  src_files,
  dependencies: gtkmm_dep,
  install: false,
)
