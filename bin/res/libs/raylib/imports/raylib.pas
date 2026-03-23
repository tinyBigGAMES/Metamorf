unit raylib;

{$IF NOT (DEFINED(WIN64) OR DEFINED(LINUX64))}
  {$MESSAGE Error 'Unsupported platform'}
{$IFEND}

{$IFDEF FPC}{$MODE DELPHIUNICODE}{$ENDIF}

{$WARN SYMBOL_PLATFORM OFF}

interface

uses
  System.SysUtils;

const
  {$IFDEF MSWINDOWS}
  CLibName = 'raylib.dll';
  {$ENDIF}
  {$IFDEF LINUX}
  CLibName = 'libraylib.so';
  {$ENDIF}

const
  // Constants from #define
  RAYLIB_VERSION_MAJOR = 5;
  RAYLIB_VERSION_MINOR = 5;
  RAYLIB_VERSION_PATCH = 0;
  RAYLIB_VERSION = '5.5';
  PI = 3.14159265358979;

type
  // Forward pointer declarations for structs
  PVector2 = ^Vector2;
  PVector3 = ^Vector3;
  PVector4 = ^Vector4;
  PMatrix = ^Matrix;
  PColor = ^Color;
  PRectangle = ^Rectangle;
  PImage = ^Image;
  PTexture = ^Texture;
  PRenderTexture = ^RenderTexture;
  PNPatchInfo = ^NPatchInfo;
  PGlyphInfo = ^GlyphInfo;
  PFont = ^Font;
  PCamera3D = ^Camera3D;
  PCamera2D = ^Camera2D;
  PMesh = ^Mesh;
  PShader = ^Shader;
  PMaterialMap = ^MaterialMap;
  PMaterial = ^Material;
  PTransform = ^Transform;
  PBoneInfo = ^BoneInfo;
  PModel = ^Model;
  PModelAnimation = ^ModelAnimation;
  PRay = ^Ray;
  PRayCollision = ^RayCollision;
  PBoundingBox = ^BoundingBox;
  PWave = ^Wave;
  PAudioStream = ^AudioStream;
  PSound = ^Sound;
  PMusic = ^Music;
  PVrDeviceInfo = ^VrDeviceInfo;
  PVrStereoConfig = ^VrStereoConfig;
  PFilePathList = ^FilePathList;
  PAutomationEvent = ^AutomationEvent;
  PAutomationEventList = ^AutomationEventList;

  // Forward pointer declarations for opaque types
  PrAudioBuffer = ^rAudioBuffer;
  PrAudioProcessor = ^rAudioProcessor;

  PQuaternion = ^Quaternion;
  PTexture2D = ^Texture2D;
  PTextureCubemap = ^TextureCubemap;
  PRenderTexture2D = ^RenderTexture2D;
  PCamera = ^Camera;

  // Opaque type definitions
  rAudioBuffer = record end;
  rAudioProcessor = record end;

  // Enums
  ConfigFlags = (
    FLAG_VSYNC_HINT = 64,
    FLAG_FULLSCREEN_MODE = 2,
    FLAG_WINDOW_RESIZABLE = 4,
    FLAG_WINDOW_UNDECORATED = 8,
    FLAG_WINDOW_HIDDEN = 128,
    FLAG_WINDOW_MINIMIZED = 512,
    FLAG_WINDOW_MAXIMIZED = 1024,
    FLAG_WINDOW_UNFOCUSED = 2048,
    FLAG_WINDOW_TOPMOST = 4096,
    FLAG_WINDOW_ALWAYS_RUN = 256,
    FLAG_WINDOW_TRANSPARENT = 16,
    FLAG_WINDOW_HIGHDPI = 8192,
    FLAG_WINDOW_MOUSE_PASSTHROUGH = 16384,
    FLAG_BORDERLESS_WINDOWED_MODE = 32768,
    FLAG_MSAA_4X_HINT = 32,
    FLAG_INTERLACED_HINT = 65536
  );

  TraceLogLevel = (
    LOG_ALL = 0,
    LOG_TRACE,
    LOG_DEBUG,
    LOG_INFO,
    LOG_WARNING,
    LOG_ERROR,
    LOG_FATAL,
    LOG_NONE
  );

  KeyboardKey = (
    KEY_NULL = 0,
    KEY_APOSTROPHE = 39,
    KEY_COMMA = 44,
    KEY_MINUS = 45,
    KEY_PERIOD = 46,
    KEY_SLASH = 47,
    KEY_ZERO = 48,
    KEY_ONE = 49,
    KEY_TWO = 50,
    KEY_THREE = 51,
    KEY_FOUR = 52,
    KEY_FIVE = 53,
    KEY_SIX = 54,
    KEY_SEVEN = 55,
    KEY_EIGHT = 56,
    KEY_NINE = 57,
    KEY_SEMICOLON = 59,
    KEY_EQUAL = 61,
    KEY_A = 65,
    KEY_B = 66,
    KEY_C = 67,
    KEY_D = 68,
    KEY_E = 69,
    KEY_F = 70,
    KEY_G = 71,
    KEY_H = 72,
    KEY_I = 73,
    KEY_J = 74,
    KEY_K = 75,
    KEY_L = 76,
    KEY_M = 77,
    KEY_N = 78,
    KEY_O = 79,
    KEY_P = 80,
    KEY_Q = 81,
    KEY_R = 82,
    KEY_S = 83,
    KEY_T = 84,
    KEY_U = 85,
    KEY_V = 86,
    KEY_W = 87,
    KEY_X = 88,
    KEY_Y = 89,
    KEY_Z = 90,
    KEY_LEFT_BRACKET = 91,
    KEY_BACKSLASH = 92,
    KEY_RIGHT_BRACKET = 93,
    KEY_GRAVE = 96,
    KEY_SPACE = 32,
    KEY_ESCAPE = 256,
    KEY_ENTER = 257,
    KEY_TAB = 258,
    KEY_BACKSPACE = 259,
    KEY_INSERT = 260,
    KEY_DELETE = 261,
    KEY_RIGHT = 262,
    KEY_LEFT = 263,
    KEY_DOWN = 264,
    KEY_UP = 265,
    KEY_PAGE_UP = 266,
    KEY_PAGE_DOWN = 267,
    KEY_HOME = 268,
    KEY_END = 269,
    KEY_CAPS_LOCK = 280,
    KEY_SCROLL_LOCK = 281,
    KEY_NUM_LOCK = 282,
    KEY_PRINT_SCREEN = 283,
    KEY_PAUSE = 284,
    KEY_F1 = 290,
    KEY_F2 = 291,
    KEY_F3 = 292,
    KEY_F4 = 293,
    KEY_F5 = 294,
    KEY_F6 = 295,
    KEY_F7 = 296,
    KEY_F8 = 297,
    KEY_F9 = 298,
    KEY_F10 = 299,
    KEY_F11 = 300,
    KEY_F12 = 301,
    KEY_LEFT_SHIFT = 340,
    KEY_LEFT_CONTROL = 341,
    KEY_LEFT_ALT = 342,
    KEY_LEFT_SUPER = 343,
    KEY_RIGHT_SHIFT = 344,
    KEY_RIGHT_CONTROL = 345,
    KEY_RIGHT_ALT = 346,
    KEY_RIGHT_SUPER = 347,
    KEY_KB_MENU = 348,
    KEY_KP_0 = 320,
    KEY_KP_1 = 321,
    KEY_KP_2 = 322,
    KEY_KP_3 = 323,
    KEY_KP_4 = 324,
    KEY_KP_5 = 325,
    KEY_KP_6 = 326,
    KEY_KP_7 = 327,
    KEY_KP_8 = 328,
    KEY_KP_9 = 329,
    KEY_KP_DECIMAL = 330,
    KEY_KP_DIVIDE = 331,
    KEY_KP_MULTIPLY = 332,
    KEY_KP_SUBTRACT = 333,
    KEY_KP_ADD = 334,
    KEY_KP_ENTER = 335,
    KEY_KP_EQUAL = 336,
    KEY_BACK = 4,
    KEY_MENU = 5,
    KEY_VOLUME_UP = 24,
    KEY_VOLUME_DOWN = 25
  );

  MouseButton = (
    MOUSE_BUTTON_LEFT = 0,
    MOUSE_BUTTON_RIGHT = 1,
    MOUSE_BUTTON_MIDDLE = 2,
    MOUSE_BUTTON_SIDE = 3,
    MOUSE_BUTTON_EXTRA = 4,
    MOUSE_BUTTON_FORWARD = 5,
    MOUSE_BUTTON_BACK = 6
  );

  MouseCursor = (
    MOUSE_CURSOR_DEFAULT = 0,
    MOUSE_CURSOR_ARROW = 1,
    MOUSE_CURSOR_IBEAM = 2,
    MOUSE_CURSOR_CROSSHAIR = 3,
    MOUSE_CURSOR_POINTING_HAND = 4,
    MOUSE_CURSOR_RESIZE_EW = 5,
    MOUSE_CURSOR_RESIZE_NS = 6,
    MOUSE_CURSOR_RESIZE_NWSE = 7,
    MOUSE_CURSOR_RESIZE_NESW = 8,
    MOUSE_CURSOR_RESIZE_ALL = 9,
    MOUSE_CURSOR_NOT_ALLOWED = 10
  );

  GamepadButton = (
    GAMEPAD_BUTTON_UNKNOWN = 0,
    GAMEPAD_BUTTON_LEFT_FACE_UP,
    GAMEPAD_BUTTON_LEFT_FACE_RIGHT,
    GAMEPAD_BUTTON_LEFT_FACE_DOWN,
    GAMEPAD_BUTTON_LEFT_FACE_LEFT,
    GAMEPAD_BUTTON_RIGHT_FACE_UP,
    GAMEPAD_BUTTON_RIGHT_FACE_RIGHT,
    GAMEPAD_BUTTON_RIGHT_FACE_DOWN,
    GAMEPAD_BUTTON_RIGHT_FACE_LEFT,
    GAMEPAD_BUTTON_LEFT_TRIGGER_1,
    GAMEPAD_BUTTON_LEFT_TRIGGER_2,
    GAMEPAD_BUTTON_RIGHT_TRIGGER_1,
    GAMEPAD_BUTTON_RIGHT_TRIGGER_2,
    GAMEPAD_BUTTON_MIDDLE_LEFT,
    GAMEPAD_BUTTON_MIDDLE,
    GAMEPAD_BUTTON_MIDDLE_RIGHT,
    GAMEPAD_BUTTON_LEFT_THUMB,
    GAMEPAD_BUTTON_RIGHT_THUMB
  );

  GamepadAxis = (
    GAMEPAD_AXIS_LEFT_X = 0,
    GAMEPAD_AXIS_LEFT_Y = 1,
    GAMEPAD_AXIS_RIGHT_X = 2,
    GAMEPAD_AXIS_RIGHT_Y = 3,
    GAMEPAD_AXIS_LEFT_TRIGGER = 4,
    GAMEPAD_AXIS_RIGHT_TRIGGER = 5
  );

  MaterialMapIndex = (
    MATERIAL_MAP_ALBEDO = 0,
    MATERIAL_MAP_METALNESS,
    MATERIAL_MAP_NORMAL,
    MATERIAL_MAP_ROUGHNESS,
    MATERIAL_MAP_OCCLUSION,
    MATERIAL_MAP_EMISSION,
    MATERIAL_MAP_HEIGHT,
    MATERIAL_MAP_CUBEMAP,
    MATERIAL_MAP_IRRADIANCE,
    MATERIAL_MAP_PREFILTER,
    MATERIAL_MAP_BRDF
  );

  ShaderLocationIndex = (
    SHADER_LOC_VERTEX_POSITION = 0,
    SHADER_LOC_VERTEX_TEXCOORD01,
    SHADER_LOC_VERTEX_TEXCOORD02,
    SHADER_LOC_VERTEX_NORMAL,
    SHADER_LOC_VERTEX_TANGENT,
    SHADER_LOC_VERTEX_COLOR,
    SHADER_LOC_MATRIX_MVP,
    SHADER_LOC_MATRIX_VIEW,
    SHADER_LOC_MATRIX_PROJECTION,
    SHADER_LOC_MATRIX_MODEL,
    SHADER_LOC_MATRIX_NORMAL,
    SHADER_LOC_VECTOR_VIEW,
    SHADER_LOC_COLOR_DIFFUSE,
    SHADER_LOC_COLOR_SPECULAR,
    SHADER_LOC_COLOR_AMBIENT,
    SHADER_LOC_MAP_ALBEDO,
    SHADER_LOC_MAP_METALNESS,
    SHADER_LOC_MAP_NORMAL,
    SHADER_LOC_MAP_ROUGHNESS,
    SHADER_LOC_MAP_OCCLUSION,
    SHADER_LOC_MAP_EMISSION,
    SHADER_LOC_MAP_HEIGHT,
    SHADER_LOC_MAP_CUBEMAP,
    SHADER_LOC_MAP_IRRADIANCE,
    SHADER_LOC_MAP_PREFILTER,
    SHADER_LOC_MAP_BRDF,
    SHADER_LOC_VERTEX_BONEIDS,
    SHADER_LOC_VERTEX_BONEWEIGHTS,
    SHADER_LOC_BONE_MATRICES
  );

  ShaderUniformDataType = (
    SHADER_UNIFORM_FLOAT = 0,
    SHADER_UNIFORM_VEC2,
    SHADER_UNIFORM_VEC3,
    SHADER_UNIFORM_VEC4,
    SHADER_UNIFORM_INT,
    SHADER_UNIFORM_IVEC2,
    SHADER_UNIFORM_IVEC3,
    SHADER_UNIFORM_IVEC4,
    SHADER_UNIFORM_SAMPLER2D
  );

  ShaderAttributeDataType = (
    SHADER_ATTRIB_FLOAT = 0,
    SHADER_ATTRIB_VEC2,
    SHADER_ATTRIB_VEC3,
    SHADER_ATTRIB_VEC4
  );

  PixelFormat = (
    PIXELFORMAT_UNCOMPRESSED_GRAYSCALE = 1,
    PIXELFORMAT_UNCOMPRESSED_GRAY_ALPHA,
    PIXELFORMAT_UNCOMPRESSED_R5G6B5,
    PIXELFORMAT_UNCOMPRESSED_R8G8B8,
    PIXELFORMAT_UNCOMPRESSED_R5G5B5A1,
    PIXELFORMAT_UNCOMPRESSED_R4G4B4A4,
    PIXELFORMAT_UNCOMPRESSED_R8G8B8A8,
    PIXELFORMAT_UNCOMPRESSED_R32,
    PIXELFORMAT_UNCOMPRESSED_R32G32B32,
    PIXELFORMAT_UNCOMPRESSED_R32G32B32A32,
    PIXELFORMAT_UNCOMPRESSED_R16,
    PIXELFORMAT_UNCOMPRESSED_R16G16B16,
    PIXELFORMAT_UNCOMPRESSED_R16G16B16A16,
    PIXELFORMAT_COMPRESSED_DXT1_RGB,
    PIXELFORMAT_COMPRESSED_DXT1_RGBA,
    PIXELFORMAT_COMPRESSED_DXT3_RGBA,
    PIXELFORMAT_COMPRESSED_DXT5_RGBA,
    PIXELFORMAT_COMPRESSED_ETC1_RGB,
    PIXELFORMAT_COMPRESSED_ETC2_RGB,
    PIXELFORMAT_COMPRESSED_ETC2_EAC_RGBA,
    PIXELFORMAT_COMPRESSED_PVRT_RGB,
    PIXELFORMAT_COMPRESSED_PVRT_RGBA,
    PIXELFORMAT_COMPRESSED_ASTC_4x4_RGBA,
    PIXELFORMAT_COMPRESSED_ASTC_8x8_RGBA
  );

  TextureFilter = (
    TEXTURE_FILTER_POINT = 0,
    TEXTURE_FILTER_BILINEAR,
    TEXTURE_FILTER_TRILINEAR,
    TEXTURE_FILTER_ANISOTROPIC_4X,
    TEXTURE_FILTER_ANISOTROPIC_8X,
    TEXTURE_FILTER_ANISOTROPIC_16X
  );

  TextureWrap = (
    TEXTURE_WRAP_REPEAT = 0,
    TEXTURE_WRAP_CLAMP,
    TEXTURE_WRAP_MIRROR_REPEAT,
    TEXTURE_WRAP_MIRROR_CLAMP
  );

  CubemapLayout = (
    CUBEMAP_LAYOUT_AUTO_DETECT = 0,
    CUBEMAP_LAYOUT_LINE_VERTICAL,
    CUBEMAP_LAYOUT_LINE_HORIZONTAL,
    CUBEMAP_LAYOUT_CROSS_THREE_BY_FOUR,
    CUBEMAP_LAYOUT_CROSS_FOUR_BY_THREE
  );

  FontType = (
    FONT_DEFAULT = 0,
    FONT_BITMAP,
    FONT_SDF
  );

  BlendMode = (
    BLEND_ALPHA = 0,
    BLEND_ADDITIVE,
    BLEND_MULTIPLIED,
    BLEND_ADD_COLORS,
    BLEND_SUBTRACT_COLORS,
    BLEND_ALPHA_PREMULTIPLY,
    BLEND_CUSTOM,
    BLEND_CUSTOM_SEPARATE
  );

  Gesture = (
    GESTURE_NONE = 0,
    GESTURE_TAP = 1,
    GESTURE_DOUBLETAP = 2,
    GESTURE_HOLD = 4,
    GESTURE_DRAG = 8,
    GESTURE_SWIPE_RIGHT = 16,
    GESTURE_SWIPE_LEFT = 32,
    GESTURE_SWIPE_UP = 64,
    GESTURE_SWIPE_DOWN = 128,
    GESTURE_PINCH_IN = 256,
    GESTURE_PINCH_OUT = 512
  );

  CameraMode = (
    CAMERA_CUSTOM = 0,
    CAMERA_FREE,
    CAMERA_ORBITAL,
    CAMERA_FIRST_PERSON,
    CAMERA_THIRD_PERSON
  );

  CameraProjection = (
    CAMERA_PERSPECTIVE = 0,
    CAMERA_ORTHOGRAPHIC
  );

  NPatchLayout = (
    NPATCH_NINE_PATCH = 0,
    NPATCH_THREE_PATCH_VERTICAL,
    NPATCH_THREE_PATCH_HORIZONTAL
  );

  // Records
  Vector2 = record
    x: Single;
    y: Single;
  end;

  Vector3 = record
    x: Single;
    y: Single;
    z: Single;
  end;

  Vector4 = record
    x: Single;
    y: Single;
    z: Single;
    w: Single;
  end;

  Matrix = record
    m0: Single;
    m4: Single;
    m8: Single;
    m12: Single;
    m1: Single;
    m5: Single;
    m9: Single;
    m13: Single;
    m2: Single;
    m6: Single;
    m10: Single;
    m14: Single;
    m3: Single;
    m7: Single;
    m11: Single;
    m15: Single;
  end;

  Color = record
    r: Byte;
    g: Byte;
    b: Byte;
    a: Byte;
  end;

  Rectangle = record
    x: Single;
    y: Single;
    width: Single;
    height: Single;
  end;

  Image = record
    data: Pointer;
    width: Int32;
    height: Int32;
    mipmaps: Int32;
    format: Int32;
  end;

  Texture = record
    id: UInt32;
    width: Int32;
    height: Int32;
    mipmaps: Int32;
    format: Int32;
  end;

  RenderTexture = record
    id: UInt32;
    texture: Texture;
    depth: Texture;
  end;

  NPatchInfo = record
    source: Rectangle;
    left: Int32;
    top: Int32;
    right: Int32;
    bottom: Int32;
    layout: Int32;
  end;

  GlyphInfo = record
    value: Int32;
    offsetX: Int32;
    offsetY: Int32;
    advanceX: Int32;
    image: Image;
  end;

  Font = record
    baseSize: Int32;
    glyphCount: Int32;
    glyphPadding: Int32;
    texture: Texture;
    recs: PRectangle;
    glyphs: PGlyphInfo;
  end;

  Camera3D = record
    position: Vector3;
    target: Vector3;
    up: Vector3;
    fovy: Single;
    projection: Int32;
  end;

  Camera2D = record
    offset: Vector2;
    target: Vector2;
    rotation: Single;
    zoom: Single;
  end;

  Mesh = record
    vertexCount: Int32;
    triangleCount: Int32;
    vertices: Pointer;
    texcoords: Pointer;
    texcoords2: Pointer;
    normals: Pointer;
    tangents: Pointer;
    colors: PByte;
    indices: Pointer;
    animVertices: Pointer;
    animNormals: Pointer;
    boneIds: PByte;
    boneWeights: Pointer;
    boneMatrices: PMatrix;
    boneCount: Int32;
    vaoId: UInt32;
    vboId: Pointer;
  end;

  Shader = record
    id: UInt32;
    locs: Pointer;
  end;

  MaterialMap = record
    texture: Texture;
    color: Color;
    value: Single;
  end;

  Material = record
    shader: Shader;
    maps: PMaterialMap;
    params: array[0..3] of Single;
  end;

  Transform = record
    translation: Vector3;
    rotation: Vector4;
    scale: Vector3;
  end;

  BoneInfo = record
    name: array[0..31] of AnsiChar;
    parent: Int32;
  end;

  Model = record
    transform: Matrix;
    meshCount: Int32;
    materialCount: Int32;
    meshes: PMesh;
    materials: PMaterial;
    meshMaterial: Pointer;
    boneCount: Int32;
    bones: PBoneInfo;
    bindPose: PTransform;
  end;

  ModelAnimation = record
    boneCount: Int32;
    frameCount: Int32;
    bones: PBoneInfo;
    framePoses: Pointer;
    name: array[0..31] of AnsiChar;
  end;

  Ray = record
    position: Vector3;
    direction: Vector3;
  end;

  RayCollision = record
    hit: Boolean;
    distance: Single;
    point: Vector3;
    normal: Vector3;
  end;

  BoundingBox = record
    min: Vector3;
    max: Vector3;
  end;

  Wave = record
    frameCount: UInt32;
    sampleRate: UInt32;
    sampleSize: UInt32;
    channels: UInt32;
    data: Pointer;
  end;

  AudioStream = record
    buffer: PrAudioBuffer;
    processor: PrAudioProcessor;
    sampleRate: UInt32;
    sampleSize: UInt32;
    channels: UInt32;
  end;

  Sound = record
    stream: AudioStream;
    frameCount: UInt32;
  end;

  Music = record
    stream: AudioStream;
    frameCount: UInt32;
    looping: Boolean;
    ctxType: Int32;
    ctxData: Pointer;
  end;

  VrDeviceInfo = record
    hResolution: Int32;
    vResolution: Int32;
    hScreenSize: Single;
    vScreenSize: Single;
    eyeToScreenDistance: Single;
    lensSeparationDistance: Single;
    interpupillaryDistance: Single;
    lensDistortionValues: array[0..3] of Single;
    chromaAbCorrection: array[0..3] of Single;
  end;

  VrStereoConfig = record
    projection: array[0..1] of Matrix;
    viewOffset: array[0..1] of Matrix;
    leftLensCenter: array[0..1] of Single;
    rightLensCenter: array[0..1] of Single;
    leftScreenCenter: array[0..1] of Single;
    rightScreenCenter: array[0..1] of Single;
    scale: array[0..1] of Single;
    scaleIn: array[0..1] of Single;
  end;

  FilePathList = record
    capacity: UInt32;
    count: UInt32;
    paths: Pointer;
  end;

  AutomationEvent = record
    frame: UInt32;
    type_: UInt32;
    params: array[0..3] of Int32;
  end;

  AutomationEventList = record
    capacity: UInt32;
    count: UInt32;
    events: PAutomationEvent;
  end;

  // Type aliases
  Quaternion = Vector4;
  Texture2D = Texture;
  TextureCubemap = Texture;
  RenderTexture2D = RenderTexture;
  Camera = Camera3D;

  // Function pointer types
  TraceLogCallback = procedure(const AlogLevel: Int32; const Atext: PAnsiChar; const Aargs: Pointer);
  LoadFileDataCallback = function(const AfileName: PAnsiChar; const AdataSize: Pointer): PByte;
  SaveFileDataCallback = function(const AfileName: PAnsiChar; const Adata: Pointer; const AdataSize: Int32): Boolean;
  LoadFileTextCallback = function(const AfileName: PAnsiChar): PAnsiChar;
  SaveFileTextCallback = function(const AfileName: PAnsiChar; const Atext: PAnsiChar): Boolean;
  AudioCallback = procedure(const AbufferData: Pointer; const Aframes: UInt32);

const
  // Typed constants from compound literals
  LIGHTGRAY: Color = (r: 200; g: 200; b: 200; a: 255);
  GRAY: Color = (r: 130; g: 130; b: 130; a: 255);
  DARKGRAY: Color = (r: 80; g: 80; b: 80; a: 255);
  YELLOW: Color = (r: 253; g: 249; b: 0; a: 255);
  GOLD: Color = (r: 255; g: 203; b: 0; a: 255);
  ORANGE: Color = (r: 255; g: 161; b: 0; a: 255);
  PINK: Color = (r: 255; g: 109; b: 194; a: 255);
  RED: Color = (r: 230; g: 41; b: 55; a: 255);
  MAROON: Color = (r: 190; g: 33; b: 55; a: 255);
  GREEN: Color = (r: 0; g: 228; b: 48; a: 255);
  LIME: Color = (r: 0; g: 158; b: 47; a: 255);
  DARKGREEN: Color = (r: 0; g: 117; b: 44; a: 255);
  SKYBLUE: Color = (r: 102; g: 191; b: 255; a: 255);
  BLUE: Color = (r: 0; g: 121; b: 241; a: 255);
  DARKBLUE: Color = (r: 0; g: 82; b: 172; a: 255);
  PURPLE: Color = (r: 200; g: 122; b: 255; a: 255);
  VIOLET: Color = (r: 135; g: 60; b: 190; a: 255);
  DARKPURPLE: Color = (r: 112; g: 31; b: 126; a: 255);
  BEIGE: Color = (r: 211; g: 176; b: 131; a: 255);
  BROWN: Color = (r: 127; g: 106; b: 79; a: 255);
  DARKBROWN: Color = (r: 76; g: 63; b: 47; a: 255);
  WHITE: Color = (r: 255; g: 255; b: 255; a: 255);
  BLACK: Color = (r: 0; g: 0; b: 0; a: 255);
  BLANK: Color = (r: 0; g: 0; b: 0; a: 0);
  MAGENTA: Color = (r: 255; g: 0; b: 255; a: 255);
  RAYWHITE: Color = (r: 245; g: 245; b: 245; a: 255);

// External functions
procedure InitWindow(const Awidth: Int32; const Aheight: Int32; const Atitle: PAnsiChar); external CLibName delayed;
procedure CloseWindow(); external CLibName delayed;
function  WindowShouldClose(): Boolean; external CLibName delayed;
function  IsWindowReady(): Boolean; external CLibName delayed;
function  IsWindowFullscreen(): Boolean; external CLibName delayed;
function  IsWindowHidden(): Boolean; external CLibName delayed;
function  IsWindowMinimized(): Boolean; external CLibName delayed;
function  IsWindowMaximized(): Boolean; external CLibName delayed;
function  IsWindowFocused(): Boolean; external CLibName delayed;
function  IsWindowResized(): Boolean; external CLibName delayed;
function  IsWindowState(const Aflag: UInt32): Boolean; external CLibName delayed;
procedure SetWindowState(const Aflags: UInt32); external CLibName delayed;
procedure ClearWindowState(const Aflags: UInt32); external CLibName delayed;
procedure ToggleFullscreen(); external CLibName delayed;
procedure ToggleBorderlessWindowed(); external CLibName delayed;
procedure MaximizeWindow(); external CLibName delayed;
procedure MinimizeWindow(); external CLibName delayed;
procedure RestoreWindow(); external CLibName delayed;
procedure SetWindowIcon(const Aimage: Image); external CLibName delayed;
procedure SetWindowIcons(const Aimages: PImage; const Acount: Int32); external CLibName delayed;
procedure SetWindowTitle(const Atitle: PAnsiChar); external CLibName delayed;
procedure SetWindowPosition(const Ax: Int32; const Ay: Int32); external CLibName delayed;
procedure SetWindowMonitor(const Amonitor: Int32); external CLibName delayed;
procedure SetWindowMinSize(const Awidth: Int32; const Aheight: Int32); external CLibName delayed;
procedure SetWindowMaxSize(const Awidth: Int32; const Aheight: Int32); external CLibName delayed;
procedure SetWindowSize(const Awidth: Int32; const Aheight: Int32); external CLibName delayed;
procedure SetWindowOpacity(const Aopacity: Single); external CLibName delayed;
procedure SetWindowFocused(); external CLibName delayed;
function  GetWindowHandle(): Pointer; external CLibName delayed;
function  GetScreenWidth(): Int32; external CLibName delayed;
function  GetScreenHeight(): Int32; external CLibName delayed;
function  GetRenderWidth(): Int32; external CLibName delayed;
function  GetRenderHeight(): Int32; external CLibName delayed;
function  GetMonitorCount(): Int32; external CLibName delayed;
function  GetCurrentMonitor(): Int32; external CLibName delayed;
function  GetMonitorPosition(const Amonitor: Int32): Vector2; external CLibName delayed;
function  GetMonitorWidth(const Amonitor: Int32): Int32; external CLibName delayed;
function  GetMonitorHeight(const Amonitor: Int32): Int32; external CLibName delayed;
function  GetMonitorPhysicalWidth(const Amonitor: Int32): Int32; external CLibName delayed;
function  GetMonitorPhysicalHeight(const Amonitor: Int32): Int32; external CLibName delayed;
function  GetMonitorRefreshRate(const Amonitor: Int32): Int32; external CLibName delayed;
function  GetWindowPosition(): Vector2; external CLibName delayed;
function  GetWindowScaleDPI(): Vector2; external CLibName delayed;
function  GetMonitorName(const Amonitor: Int32): PAnsiChar; external CLibName delayed;
procedure SetClipboardText(const Atext: PAnsiChar); external CLibName delayed;
function  GetClipboardText(): PAnsiChar; external CLibName delayed;
function  GetClipboardImage(): Image; external CLibName delayed;
procedure EnableEventWaiting(); external CLibName delayed;
procedure DisableEventWaiting(); external CLibName delayed;
procedure ShowCursor(); external CLibName delayed;
procedure HideCursor(); external CLibName delayed;
function  IsCursorHidden(): Boolean; external CLibName delayed;
procedure EnableCursor(); external CLibName delayed;
procedure DisableCursor(); external CLibName delayed;
function  IsCursorOnScreen(): Boolean; external CLibName delayed;
procedure ClearBackground(const Acolor: Color); external CLibName delayed;
procedure BeginDrawing(); external CLibName delayed;
procedure EndDrawing(); external CLibName delayed;
procedure BeginMode2D(const Acamera: Camera2D); external CLibName delayed;
procedure EndMode2D(); external CLibName delayed;
procedure BeginMode3D(const Acamera: Camera3D); external CLibName delayed;
procedure EndMode3D(); external CLibName delayed;
procedure BeginTextureMode(const Atarget: RenderTexture2D); external CLibName delayed;
procedure EndTextureMode(); external CLibName delayed;
procedure BeginShaderMode(const Ashader: Shader); external CLibName delayed;
procedure EndShaderMode(); external CLibName delayed;
procedure BeginBlendMode(const Amode: Int32); external CLibName delayed;
procedure EndBlendMode(); external CLibName delayed;
procedure BeginScissorMode(const Ax: Int32; const Ay: Int32; const Awidth: Int32; const Aheight: Int32); external CLibName delayed;
procedure EndScissorMode(); external CLibName delayed;
procedure BeginVrStereoMode(const Aconfig: VrStereoConfig); external CLibName delayed;
procedure EndVrStereoMode(); external CLibName delayed;
function  LoadVrStereoConfig(const Adevice: VrDeviceInfo): VrStereoConfig; external CLibName delayed;
procedure UnloadVrStereoConfig(const Aconfig: VrStereoConfig); external CLibName delayed;
function  LoadShader(const AvsFileName: PAnsiChar; const AfsFileName: PAnsiChar): Shader; external CLibName delayed;
function  LoadShaderFromMemory(const AvsCode: PAnsiChar; const AfsCode: PAnsiChar): Shader; external CLibName delayed;
function  IsShaderValid(const Ashader: Shader): Boolean; external CLibName delayed;
function  GetShaderLocation(const Ashader: Shader; const AuniformName: PAnsiChar): Int32; external CLibName delayed;
function  GetShaderLocationAttrib(const Ashader: Shader; const AattribName: PAnsiChar): Int32; external CLibName delayed;
procedure SetShaderValue(const Ashader: Shader; const AlocIndex: Int32; const Avalue: Pointer; const AuniformType: Int32); external CLibName delayed;
procedure SetShaderValueV(const Ashader: Shader; const AlocIndex: Int32; const Avalue: Pointer; const AuniformType: Int32; const Acount: Int32); external CLibName delayed;
procedure SetShaderValueMatrix(const Ashader: Shader; const AlocIndex: Int32; const Amat: Matrix); external CLibName delayed;
procedure SetShaderValueTexture(const Ashader: Shader; const AlocIndex: Int32; const Atexture: Texture2D); external CLibName delayed;
procedure UnloadShader(const Ashader: Shader); external CLibName delayed;
function  GetScreenToWorldRay(const Aposition: Vector2; const Acamera: Camera): Ray; external CLibName delayed;
function  GetScreenToWorldRayEx(const Aposition: Vector2; const Acamera: Camera; const Awidth: Int32; const Aheight: Int32): Ray; external CLibName delayed;
function  GetWorldToScreen(const Aposition: Vector3; const Acamera: Camera): Vector2; external CLibName delayed;
function  GetWorldToScreenEx(const Aposition: Vector3; const Acamera: Camera; const Awidth: Int32; const Aheight: Int32): Vector2; external CLibName delayed;
function  GetWorldToScreen2D(const Aposition: Vector2; const Acamera: Camera2D): Vector2; external CLibName delayed;
function  GetScreenToWorld2D(const Aposition: Vector2; const Acamera: Camera2D): Vector2; external CLibName delayed;
function  GetCameraMatrix(const Acamera: Camera): Matrix; external CLibName delayed;
function  GetCameraMatrix2D(const Acamera: Camera2D): Matrix; external CLibName delayed;
procedure SetTargetFPS(const Afps: Int32); external CLibName delayed;
function  GetFrameTime(): Single; external CLibName delayed;
function  GetTime(): Double; external CLibName delayed;
function  GetFPS(): Int32; external CLibName delayed;
procedure SwapScreenBuffer(); external CLibName delayed;
procedure PollInputEvents(); external CLibName delayed;
procedure WaitTime(const Aseconds: Double); external CLibName delayed;
procedure SetRandomSeed(const Aseed: UInt32); external CLibName delayed;
function  GetRandomValue(const Amin: Int32; const Amax: Int32): Int32; external CLibName delayed;
function  LoadRandomSequence(const Acount: UInt32; const Amin: Int32; const Amax: Int32): Pointer; external CLibName delayed;
procedure UnloadRandomSequence(const Asequence: Pointer); external CLibName delayed;
procedure TakeScreenshot(const AfileName: PAnsiChar); external CLibName delayed;
procedure SetConfigFlags(const Aflags: UInt32); external CLibName delayed;
procedure OpenURL(const Aurl: PAnsiChar); external CLibName delayed;
procedure TraceLog(const AlogLevel: Int32; const Atext: PAnsiChar); varargs; external CLibName delayed;
procedure SetTraceLogLevel(const AlogLevel: Int32); external CLibName delayed;
function  MemAlloc(const Asize: UInt32): Pointer; external CLibName delayed;
function  MemRealloc(const Aptr: Pointer; const Asize: UInt32): Pointer; external CLibName delayed;
procedure MemFree(const Aptr: Pointer); external CLibName delayed;
procedure SetTraceLogCallback(const Acallback: TraceLogCallback); external CLibName delayed;
procedure SetLoadFileDataCallback(const Acallback: LoadFileDataCallback); external CLibName delayed;
procedure SetSaveFileDataCallback(const Acallback: SaveFileDataCallback); external CLibName delayed;
procedure SetLoadFileTextCallback(const Acallback: LoadFileTextCallback); external CLibName delayed;
procedure SetSaveFileTextCallback(const Acallback: SaveFileTextCallback); external CLibName delayed;
function  LoadFileData(const AfileName: PAnsiChar; const AdataSize: Pointer): PByte; external CLibName delayed;
procedure UnloadFileData(const Adata: PByte); external CLibName delayed;
function  SaveFileData(const AfileName: PAnsiChar; const Adata: Pointer; const AdataSize: Int32): Boolean; external CLibName delayed;
function  ExportDataAsCode(const Adata: PByte; const AdataSize: Int32; const AfileName: PAnsiChar): Boolean; external CLibName delayed;
function  LoadFileText(const AfileName: PAnsiChar): PAnsiChar; external CLibName delayed;
procedure UnloadFileText(const Atext: PAnsiChar); external CLibName delayed;
function  SaveFileText(const AfileName: PAnsiChar; const Atext: PAnsiChar): Boolean; external CLibName delayed;
function  FileExists(const AfileName: PAnsiChar): Boolean; external CLibName delayed;
function  DirectoryExists(const AdirPath: PAnsiChar): Boolean; external CLibName delayed;
function  IsFileExtension(const AfileName: PAnsiChar; const Aext: PAnsiChar): Boolean; external CLibName delayed;
function  GetFileLength(const AfileName: PAnsiChar): Int32; external CLibName delayed;
function  GetFileExtension(const AfileName: PAnsiChar): PAnsiChar; external CLibName delayed;
function  GetFileName(const AfilePath: PAnsiChar): PAnsiChar; external CLibName delayed;
function  GetFileNameWithoutExt(const AfilePath: PAnsiChar): PAnsiChar; external CLibName delayed;
function  GetDirectoryPath(const AfilePath: PAnsiChar): PAnsiChar; external CLibName delayed;
function  GetPrevDirectoryPath(const AdirPath: PAnsiChar): PAnsiChar; external CLibName delayed;
function  GetWorkingDirectory(): PAnsiChar; external CLibName delayed;
function  GetApplicationDirectory(): PAnsiChar; external CLibName delayed;
function  MakeDirectory(const AdirPath: PAnsiChar): Int32; external CLibName delayed;
function  ChangeDirectory(const Adir: PAnsiChar): Boolean; external CLibName delayed;
function  IsPathFile(const Apath: PAnsiChar): Boolean; external CLibName delayed;
function  IsFileNameValid(const AfileName: PAnsiChar): Boolean; external CLibName delayed;
function  LoadDirectoryFiles(const AdirPath: PAnsiChar): FilePathList; external CLibName delayed;
function  LoadDirectoryFilesEx(const AbasePath: PAnsiChar; const Afilter: PAnsiChar; const AscanSubdirs: Boolean): FilePathList; external CLibName delayed;
procedure UnloadDirectoryFiles(const Afiles: FilePathList); external CLibName delayed;
function  IsFileDropped(): Boolean; external CLibName delayed;
function  LoadDroppedFiles(): FilePathList; external CLibName delayed;
procedure UnloadDroppedFiles(const Afiles: FilePathList); external CLibName delayed;
function  GetFileModTime(const AfileName: PAnsiChar): Int32; external CLibName delayed;
function  CompressData(const Adata: PByte; const AdataSize: Int32; const AcompDataSize: Pointer): PByte; external CLibName delayed;
function  DecompressData(const AcompData: PByte; const AcompDataSize: Int32; const AdataSize: Pointer): PByte; external CLibName delayed;
function  EncodeDataBase64(const Adata: PByte; const AdataSize: Int32; const AoutputSize: Pointer): PAnsiChar; external CLibName delayed;
function  DecodeDataBase64(const Adata: PByte; const AoutputSize: Pointer): PByte; external CLibName delayed;
function  ComputeCRC32(const Adata: PByte; const AdataSize: Int32): UInt32; external CLibName delayed;
function  ComputeMD5(const Adata: PByte; const AdataSize: Int32): Pointer; external CLibName delayed;
function  ComputeSHA1(const Adata: PByte; const AdataSize: Int32): Pointer; external CLibName delayed;
function  LoadAutomationEventList(const AfileName: PAnsiChar): AutomationEventList; external CLibName delayed;
procedure UnloadAutomationEventList(const Alist: AutomationEventList); external CLibName delayed;
function  ExportAutomationEventList(const Alist: AutomationEventList; const AfileName: PAnsiChar): Boolean; external CLibName delayed;
procedure SetAutomationEventList(const Alist: PAutomationEventList); external CLibName delayed;
procedure SetAutomationEventBaseFrame(const Aframe: Int32); external CLibName delayed;
procedure StartAutomationEventRecording(); external CLibName delayed;
procedure StopAutomationEventRecording(); external CLibName delayed;
procedure PlayAutomationEvent(const Aevent: AutomationEvent); external CLibName delayed;
function  IsKeyPressed(const Akey: Int32): Boolean; external CLibName delayed;
function  IsKeyPressedRepeat(const Akey: Int32): Boolean; external CLibName delayed;
function  IsKeyDown(const Akey: Int32): Boolean; external CLibName delayed;
function  IsKeyReleased(const Akey: Int32): Boolean; external CLibName delayed;
function  IsKeyUp(const Akey: Int32): Boolean; external CLibName delayed;
function  GetKeyPressed(): Int32; external CLibName delayed;
function  GetCharPressed(): Int32; external CLibName delayed;
procedure SetExitKey(const Akey: Int32); external CLibName delayed;
function  IsGamepadAvailable(const Agamepad: Int32): Boolean; external CLibName delayed;
function  GetGamepadName(const Agamepad: Int32): PAnsiChar; external CLibName delayed;
function  IsGamepadButtonPressed(const Agamepad: Int32; const Abutton: Int32): Boolean; external CLibName delayed;
function  IsGamepadButtonDown(const Agamepad: Int32; const Abutton: Int32): Boolean; external CLibName delayed;
function  IsGamepadButtonReleased(const Agamepad: Int32; const Abutton: Int32): Boolean; external CLibName delayed;
function  IsGamepadButtonUp(const Agamepad: Int32; const Abutton: Int32): Boolean; external CLibName delayed;
function  GetGamepadButtonPressed(): Int32; external CLibName delayed;
function  GetGamepadAxisCount(const Agamepad: Int32): Int32; external CLibName delayed;
function  GetGamepadAxisMovement(const Agamepad: Int32; const Aaxis: Int32): Single; external CLibName delayed;
function  SetGamepadMappings(const Amappings: PAnsiChar): Int32; external CLibName delayed;
procedure SetGamepadVibration(const Agamepad: Int32; const AleftMotor: Single; const ArightMotor: Single; const Aduration: Single); external CLibName delayed;
function  IsMouseButtonPressed(const Abutton: Int32): Boolean; external CLibName delayed;
function  IsMouseButtonDown(const Abutton: Int32): Boolean; external CLibName delayed;
function  IsMouseButtonReleased(const Abutton: Int32): Boolean; external CLibName delayed;
function  IsMouseButtonUp(const Abutton: Int32): Boolean; external CLibName delayed;
function  GetMouseX(): Int32; external CLibName delayed;
function  GetMouseY(): Int32; external CLibName delayed;
function  GetMousePosition(): Vector2; external CLibName delayed;
function  GetMouseDelta(): Vector2; external CLibName delayed;
procedure SetMousePosition(const Ax: Int32; const Ay: Int32); external CLibName delayed;
procedure SetMouseOffset(const AoffsetX: Int32; const AoffsetY: Int32); external CLibName delayed;
procedure SetMouseScale(const AscaleX: Single; const AscaleY: Single); external CLibName delayed;
function  GetMouseWheelMove(): Single; external CLibName delayed;
function  GetMouseWheelMoveV(): Vector2; external CLibName delayed;
procedure SetMouseCursor(const Acursor: Int32); external CLibName delayed;
function  GetTouchX(): Int32; external CLibName delayed;
function  GetTouchY(): Int32; external CLibName delayed;
function  GetTouchPosition(const Aindex: Int32): Vector2; external CLibName delayed;
function  GetTouchPointId(const Aindex: Int32): Int32; external CLibName delayed;
function  GetTouchPointCount(): Int32; external CLibName delayed;
procedure SetGesturesEnabled(const Aflags: UInt32); external CLibName delayed;
function  IsGestureDetected(const Agesture: UInt32): Boolean; external CLibName delayed;
function  GetGestureDetected(): Int32; external CLibName delayed;
function  GetGestureHoldDuration(): Single; external CLibName delayed;
function  GetGestureDragVector(): Vector2; external CLibName delayed;
function  GetGestureDragAngle(): Single; external CLibName delayed;
function  GetGesturePinchVector(): Vector2; external CLibName delayed;
function  GetGesturePinchAngle(): Single; external CLibName delayed;
procedure UpdateCamera(const Acamera: PCamera; const Amode: Int32); external CLibName delayed;
procedure UpdateCameraPro(const Acamera: PCamera; const Amovement: Vector3; const Arotation: Vector3; const Azoom: Single); external CLibName delayed;
procedure SetShapesTexture(const Atexture: Texture2D; const Asource: Rectangle); external CLibName delayed;
function  GetShapesTexture(): Texture2D; external CLibName delayed;
function  GetShapesTextureRectangle(): Rectangle; external CLibName delayed;
procedure DrawPixel(const AposX: Int32; const AposY: Int32; const Acolor: Color); external CLibName delayed;
procedure DrawPixelV(const Aposition: Vector2; const Acolor: Color); external CLibName delayed;
procedure DrawLine(const AstartPosX: Int32; const AstartPosY: Int32; const AendPosX: Int32; const AendPosY: Int32; const Acolor: Color); external CLibName delayed;
procedure DrawLineV(const AstartPos: Vector2; const AendPos: Vector2; const Acolor: Color); external CLibName delayed;
procedure DrawLineEx(const AstartPos: Vector2; const AendPos: Vector2; const Athick: Single; const Acolor: Color); external CLibName delayed;
procedure DrawLineStrip(const Apoints: PVector2; const ApointCount: Int32; const Acolor: Color); external CLibName delayed;
procedure DrawLineBezier(const AstartPos: Vector2; const AendPos: Vector2; const Athick: Single; const Acolor: Color); external CLibName delayed;
procedure DrawCircle(const AcenterX: Int32; const AcenterY: Int32; const Aradius: Single; const Acolor: Color); external CLibName delayed;
procedure DrawCircleSector(const Acenter: Vector2; const Aradius: Single; const AstartAngle: Single; const AendAngle: Single; const Asegments: Int32; const Acolor: Color); external CLibName delayed;
procedure DrawCircleSectorLines(const Acenter: Vector2; const Aradius: Single; const AstartAngle: Single; const AendAngle: Single; const Asegments: Int32; const Acolor: Color); external CLibName delayed;
procedure DrawCircleGradient(const AcenterX: Int32; const AcenterY: Int32; const Aradius: Single; const Ainner: Color; const Aouter: Color); external CLibName delayed;
procedure DrawCircleV(const Acenter: Vector2; const Aradius: Single; const Acolor: Color); external CLibName delayed;
procedure DrawCircleLines(const AcenterX: Int32; const AcenterY: Int32; const Aradius: Single; const Acolor: Color); external CLibName delayed;
procedure DrawCircleLinesV(const Acenter: Vector2; const Aradius: Single; const Acolor: Color); external CLibName delayed;
procedure DrawEllipse(const AcenterX: Int32; const AcenterY: Int32; const AradiusH: Single; const AradiusV: Single; const Acolor: Color); external CLibName delayed;
procedure DrawEllipseLines(const AcenterX: Int32; const AcenterY: Int32; const AradiusH: Single; const AradiusV: Single; const Acolor: Color); external CLibName delayed;
procedure DrawRing(const Acenter: Vector2; const AinnerRadius: Single; const AouterRadius: Single; const AstartAngle: Single; const AendAngle: Single; const Asegments: Int32; const Acolor: Color); external CLibName delayed;
procedure DrawRingLines(const Acenter: Vector2; const AinnerRadius: Single; const AouterRadius: Single; const AstartAngle: Single; const AendAngle: Single; const Asegments: Int32; const Acolor: Color); external CLibName delayed;
procedure DrawRectangle(const AposX: Int32; const AposY: Int32; const Awidth: Int32; const Aheight: Int32; const Acolor: Color); external CLibName delayed;
procedure DrawRectangleV(const Aposition: Vector2; const Asize: Vector2; const Acolor: Color); external CLibName delayed;
procedure DrawRectangleRec(const Arec: Rectangle; const Acolor: Color); external CLibName delayed;
procedure DrawRectanglePro(const Arec: Rectangle; const Aorigin: Vector2; const Arotation: Single; const Acolor: Color); external CLibName delayed;
procedure DrawRectangleGradientV(const AposX: Int32; const AposY: Int32; const Awidth: Int32; const Aheight: Int32; const Atop: Color; const Abottom: Color); external CLibName delayed;
procedure DrawRectangleGradientH(const AposX: Int32; const AposY: Int32; const Awidth: Int32; const Aheight: Int32; const Aleft: Color; const Aright: Color); external CLibName delayed;
procedure DrawRectangleGradientEx(const Arec: Rectangle; const AtopLeft: Color; const AbottomLeft: Color; const AtopRight: Color; const AbottomRight: Color); external CLibName delayed;
procedure DrawRectangleLines(const AposX: Int32; const AposY: Int32; const Awidth: Int32; const Aheight: Int32; const Acolor: Color); external CLibName delayed;
procedure DrawRectangleLinesEx(const Arec: Rectangle; const AlineThick: Single; const Acolor: Color); external CLibName delayed;
procedure DrawRectangleRounded(const Arec: Rectangle; const Aroundness: Single; const Asegments: Int32; const Acolor: Color); external CLibName delayed;
procedure DrawRectangleRoundedLines(const Arec: Rectangle; const Aroundness: Single; const Asegments: Int32; const Acolor: Color); external CLibName delayed;
procedure DrawRectangleRoundedLinesEx(const Arec: Rectangle; const Aroundness: Single; const Asegments: Int32; const AlineThick: Single; const Acolor: Color); external CLibName delayed;
procedure DrawTriangle(const Av1: Vector2; const Av2: Vector2; const Av3: Vector2; const Acolor: Color); external CLibName delayed;
procedure DrawTriangleLines(const Av1: Vector2; const Av2: Vector2; const Av3: Vector2; const Acolor: Color); external CLibName delayed;
procedure DrawTriangleFan(const Apoints: PVector2; const ApointCount: Int32; const Acolor: Color); external CLibName delayed;
procedure DrawTriangleStrip(const Apoints: PVector2; const ApointCount: Int32; const Acolor: Color); external CLibName delayed;
procedure DrawPoly(const Acenter: Vector2; const Asides: Int32; const Aradius: Single; const Arotation: Single; const Acolor: Color); external CLibName delayed;
procedure DrawPolyLines(const Acenter: Vector2; const Asides: Int32; const Aradius: Single; const Arotation: Single; const Acolor: Color); external CLibName delayed;
procedure DrawPolyLinesEx(const Acenter: Vector2; const Asides: Int32; const Aradius: Single; const Arotation: Single; const AlineThick: Single; const Acolor: Color); external CLibName delayed;
procedure DrawSplineLinear(const Apoints: PVector2; const ApointCount: Int32; const Athick: Single; const Acolor: Color); external CLibName delayed;
procedure DrawSplineBasis(const Apoints: PVector2; const ApointCount: Int32; const Athick: Single; const Acolor: Color); external CLibName delayed;
procedure DrawSplineCatmullRom(const Apoints: PVector2; const ApointCount: Int32; const Athick: Single; const Acolor: Color); external CLibName delayed;
procedure DrawSplineBezierQuadratic(const Apoints: PVector2; const ApointCount: Int32; const Athick: Single; const Acolor: Color); external CLibName delayed;
procedure DrawSplineBezierCubic(const Apoints: PVector2; const ApointCount: Int32; const Athick: Single; const Acolor: Color); external CLibName delayed;
procedure DrawSplineSegmentLinear(const Ap1: Vector2; const Ap2: Vector2; const Athick: Single; const Acolor: Color); external CLibName delayed;
procedure DrawSplineSegmentBasis(const Ap1: Vector2; const Ap2: Vector2; const Ap3: Vector2; const Ap4: Vector2; const Athick: Single; const Acolor: Color); external CLibName delayed;
procedure DrawSplineSegmentCatmullRom(const Ap1: Vector2; const Ap2: Vector2; const Ap3: Vector2; const Ap4: Vector2; const Athick: Single; const Acolor: Color); external CLibName delayed;
procedure DrawSplineSegmentBezierQuadratic(const Ap1: Vector2; const Ac2: Vector2; const Ap3: Vector2; const Athick: Single; const Acolor: Color); external CLibName delayed;
procedure DrawSplineSegmentBezierCubic(const Ap1: Vector2; const Ac2: Vector2; const Ac3: Vector2; const Ap4: Vector2; const Athick: Single; const Acolor: Color); external CLibName delayed;
function  GetSplinePointLinear(const AstartPos: Vector2; const AendPos: Vector2; const At: Single): Vector2; external CLibName delayed;
function  GetSplinePointBasis(const Ap1: Vector2; const Ap2: Vector2; const Ap3: Vector2; const Ap4: Vector2; const At: Single): Vector2; external CLibName delayed;
function  GetSplinePointCatmullRom(const Ap1: Vector2; const Ap2: Vector2; const Ap3: Vector2; const Ap4: Vector2; const At: Single): Vector2; external CLibName delayed;
function  GetSplinePointBezierQuad(const Ap1: Vector2; const Ac2: Vector2; const Ap3: Vector2; const At: Single): Vector2; external CLibName delayed;
function  GetSplinePointBezierCubic(const Ap1: Vector2; const Ac2: Vector2; const Ac3: Vector2; const Ap4: Vector2; const At: Single): Vector2; external CLibName delayed;
function  CheckCollisionRecs(const Arec1: Rectangle; const Arec2: Rectangle): Boolean; external CLibName delayed;
function  CheckCollisionCircles(const Acenter1: Vector2; const Aradius1: Single; const Acenter2: Vector2; const Aradius2: Single): Boolean; external CLibName delayed;
function  CheckCollisionCircleRec(const Acenter: Vector2; const Aradius: Single; const Arec: Rectangle): Boolean; external CLibName delayed;
function  CheckCollisionCircleLine(const Acenter: Vector2; const Aradius: Single; const Ap1: Vector2; const Ap2: Vector2): Boolean; external CLibName delayed;
function  CheckCollisionPointRec(const Apoint: Vector2; const Arec: Rectangle): Boolean; external CLibName delayed;
function  CheckCollisionPointCircle(const Apoint: Vector2; const Acenter: Vector2; const Aradius: Single): Boolean; external CLibName delayed;
function  CheckCollisionPointTriangle(const Apoint: Vector2; const Ap1: Vector2; const Ap2: Vector2; const Ap3: Vector2): Boolean; external CLibName delayed;
function  CheckCollisionPointLine(const Apoint: Vector2; const Ap1: Vector2; const Ap2: Vector2; const Athreshold: Int32): Boolean; external CLibName delayed;
function  CheckCollisionPointPoly(const Apoint: Vector2; const Apoints: PVector2; const ApointCount: Int32): Boolean; external CLibName delayed;
function  CheckCollisionLines(const AstartPos1: Vector2; const AendPos1: Vector2; const AstartPos2: Vector2; const AendPos2: Vector2; const AcollisionPoint: PVector2): Boolean; external CLibName delayed;
function  GetCollisionRec(const Arec1: Rectangle; const Arec2: Rectangle): Rectangle; external CLibName delayed;
function  LoadImage(const AfileName: PAnsiChar): Image; external CLibName delayed;
function  LoadImageRaw(const AfileName: PAnsiChar; const Awidth: Int32; const Aheight: Int32; const Aformat: Int32; const AheaderSize: Int32): Image; external CLibName delayed;
function  LoadImageAnim(const AfileName: PAnsiChar; const Aframes: Pointer): Image; external CLibName delayed;
function  LoadImageAnimFromMemory(const AfileType: PAnsiChar; const AfileData: PByte; const AdataSize: Int32; const Aframes: Pointer): Image; external CLibName delayed;
function  LoadImageFromMemory(const AfileType: PAnsiChar; const AfileData: PByte; const AdataSize: Int32): Image; external CLibName delayed;
function  LoadImageFromTexture(const Atexture: Texture2D): Image; external CLibName delayed;
function  LoadImageFromScreen(): Image; external CLibName delayed;
function  IsImageValid(const Aimage: Image): Boolean; external CLibName delayed;
procedure UnloadImage(const Aimage: Image); external CLibName delayed;
function  ExportImage(const Aimage: Image; const AfileName: PAnsiChar): Boolean; external CLibName delayed;
function  ExportImageToMemory(const Aimage: Image; const AfileType: PAnsiChar; const AfileSize: Pointer): PByte; external CLibName delayed;
function  ExportImageAsCode(const Aimage: Image; const AfileName: PAnsiChar): Boolean; external CLibName delayed;
function  GenImageColor(const Awidth: Int32; const Aheight: Int32; const Acolor: Color): Image; external CLibName delayed;
function  GenImageGradientLinear(const Awidth: Int32; const Aheight: Int32; const Adirection: Int32; const Astart: Color; const Aend: Color): Image; external CLibName delayed;
function  GenImageGradientRadial(const Awidth: Int32; const Aheight: Int32; const Adensity: Single; const Ainner: Color; const Aouter: Color): Image; external CLibName delayed;
function  GenImageGradientSquare(const Awidth: Int32; const Aheight: Int32; const Adensity: Single; const Ainner: Color; const Aouter: Color): Image; external CLibName delayed;
function  GenImageChecked(const Awidth: Int32; const Aheight: Int32; const AchecksX: Int32; const AchecksY: Int32; const Acol1: Color; const Acol2: Color): Image; external CLibName delayed;
function  GenImageWhiteNoise(const Awidth: Int32; const Aheight: Int32; const Afactor: Single): Image; external CLibName delayed;
function  GenImagePerlinNoise(const Awidth: Int32; const Aheight: Int32; const AoffsetX: Int32; const AoffsetY: Int32; const Ascale: Single): Image; external CLibName delayed;
function  GenImageCellular(const Awidth: Int32; const Aheight: Int32; const AtileSize: Int32): Image; external CLibName delayed;
function  GenImageText(const Awidth: Int32; const Aheight: Int32; const Atext: PAnsiChar): Image; external CLibName delayed;
function  ImageCopy(const Aimage: Image): Image; external CLibName delayed;
function  ImageFromImage(const Aimage: Image; const Arec: Rectangle): Image; external CLibName delayed;
function  ImageFromChannel(const Aimage: Image; const AselectedChannel: Int32): Image; external CLibName delayed;
function  ImageText(const Atext: PAnsiChar; const AfontSize: Int32; const Acolor: Color): Image; external CLibName delayed;
function  ImageTextEx(const Afont: Font; const Atext: PAnsiChar; const AfontSize: Single; const Aspacing: Single; const Atint: Color): Image; external CLibName delayed;
procedure ImageFormat(const Aimage: PImage; const AnewFormat: Int32); external CLibName delayed;
procedure ImageToPOT(const Aimage: PImage; const Afill: Color); external CLibName delayed;
procedure ImageCrop(const Aimage: PImage; const Acrop: Rectangle); external CLibName delayed;
procedure ImageAlphaCrop(const Aimage: PImage; const Athreshold: Single); external CLibName delayed;
procedure ImageAlphaClear(const Aimage: PImage; const Acolor: Color; const Athreshold: Single); external CLibName delayed;
procedure ImageAlphaMask(const Aimage: PImage; const AalphaMask: Image); external CLibName delayed;
procedure ImageAlphaPremultiply(const Aimage: PImage); external CLibName delayed;
procedure ImageBlurGaussian(const Aimage: PImage; const AblurSize: Int32); external CLibName delayed;
procedure ImageKernelConvolution(const Aimage: PImage; const Akernel: Pointer; const AkernelSize: Int32); external CLibName delayed;
procedure ImageResize(const Aimage: PImage; const AnewWidth: Int32; const AnewHeight: Int32); external CLibName delayed;
procedure ImageResizeNN(const Aimage: PImage; const AnewWidth: Int32; const AnewHeight: Int32); external CLibName delayed;
procedure ImageResizeCanvas(const Aimage: PImage; const AnewWidth: Int32; const AnewHeight: Int32; const AoffsetX: Int32; const AoffsetY: Int32; const Afill: Color); external CLibName delayed;
procedure ImageMipmaps(const Aimage: PImage); external CLibName delayed;
procedure ImageDither(const Aimage: PImage; const ArBpp: Int32; const AgBpp: Int32; const AbBpp: Int32; const AaBpp: Int32); external CLibName delayed;
procedure ImageFlipVertical(const Aimage: PImage); external CLibName delayed;
procedure ImageFlipHorizontal(const Aimage: PImage); external CLibName delayed;
procedure ImageRotate(const Aimage: PImage; const Adegrees: Int32); external CLibName delayed;
procedure ImageRotateCW(const Aimage: PImage); external CLibName delayed;
procedure ImageRotateCCW(const Aimage: PImage); external CLibName delayed;
procedure ImageColorTint(const Aimage: PImage; const Acolor: Color); external CLibName delayed;
procedure ImageColorInvert(const Aimage: PImage); external CLibName delayed;
procedure ImageColorGrayscale(const Aimage: PImage); external CLibName delayed;
procedure ImageColorContrast(const Aimage: PImage; const Acontrast: Single); external CLibName delayed;
procedure ImageColorBrightness(const Aimage: PImage; const Abrightness: Int32); external CLibName delayed;
procedure ImageColorReplace(const Aimage: PImage; const Acolor: Color; const Areplace: Color); external CLibName delayed;
function  LoadImageColors(const Aimage: Image): PColor; external CLibName delayed;
function  LoadImagePalette(const Aimage: Image; const AmaxPaletteSize: Int32; const AcolorCount: Pointer): PColor; external CLibName delayed;
procedure UnloadImageColors(const Acolors: PColor); external CLibName delayed;
procedure UnloadImagePalette(const Acolors: PColor); external CLibName delayed;
function  GetImageAlphaBorder(const Aimage: Image; const Athreshold: Single): Rectangle; external CLibName delayed;
function  GetImageColor(const Aimage: Image; const Ax: Int32; const Ay: Int32): Color; external CLibName delayed;
procedure ImageClearBackground(const Adst: PImage; const Acolor: Color); external CLibName delayed;
procedure ImageDrawPixel(const Adst: PImage; const AposX: Int32; const AposY: Int32; const Acolor: Color); external CLibName delayed;
procedure ImageDrawPixelV(const Adst: PImage; const Aposition: Vector2; const Acolor: Color); external CLibName delayed;
procedure ImageDrawLine(const Adst: PImage; const AstartPosX: Int32; const AstartPosY: Int32; const AendPosX: Int32; const AendPosY: Int32; const Acolor: Color); external CLibName delayed;
procedure ImageDrawLineV(const Adst: PImage; const Astart: Vector2; const Aend: Vector2; const Acolor: Color); external CLibName delayed;
procedure ImageDrawLineEx(const Adst: PImage; const Astart: Vector2; const Aend: Vector2; const Athick: Int32; const Acolor: Color); external CLibName delayed;
procedure ImageDrawCircle(const Adst: PImage; const AcenterX: Int32; const AcenterY: Int32; const Aradius: Int32; const Acolor: Color); external CLibName delayed;
procedure ImageDrawCircleV(const Adst: PImage; const Acenter: Vector2; const Aradius: Int32; const Acolor: Color); external CLibName delayed;
procedure ImageDrawCircleLines(const Adst: PImage; const AcenterX: Int32; const AcenterY: Int32; const Aradius: Int32; const Acolor: Color); external CLibName delayed;
procedure ImageDrawCircleLinesV(const Adst: PImage; const Acenter: Vector2; const Aradius: Int32; const Acolor: Color); external CLibName delayed;
procedure ImageDrawRectangle(const Adst: PImage; const AposX: Int32; const AposY: Int32; const Awidth: Int32; const Aheight: Int32; const Acolor: Color); external CLibName delayed;
procedure ImageDrawRectangleV(const Adst: PImage; const Aposition: Vector2; const Asize: Vector2; const Acolor: Color); external CLibName delayed;
procedure ImageDrawRectangleRec(const Adst: PImage; const Arec: Rectangle; const Acolor: Color); external CLibName delayed;
procedure ImageDrawRectangleLines(const Adst: PImage; const Arec: Rectangle; const Athick: Int32; const Acolor: Color); external CLibName delayed;
procedure ImageDrawTriangle(const Adst: PImage; const Av1: Vector2; const Av2: Vector2; const Av3: Vector2; const Acolor: Color); external CLibName delayed;
procedure ImageDrawTriangleEx(const Adst: PImage; const Av1: Vector2; const Av2: Vector2; const Av3: Vector2; const Ac1: Color; const Ac2: Color; const Ac3: Color); external CLibName delayed;
procedure ImageDrawTriangleLines(const Adst: PImage; const Av1: Vector2; const Av2: Vector2; const Av3: Vector2; const Acolor: Color); external CLibName delayed;
procedure ImageDrawTriangleFan(const Adst: PImage; const Apoints: PVector2; const ApointCount: Int32; const Acolor: Color); external CLibName delayed;
procedure ImageDrawTriangleStrip(const Adst: PImage; const Apoints: PVector2; const ApointCount: Int32; const Acolor: Color); external CLibName delayed;
procedure ImageDraw(const Adst: PImage; const Asrc: Image; const AsrcRec: Rectangle; const AdstRec: Rectangle; const Atint: Color); external CLibName delayed;
procedure ImageDrawText(const Adst: PImage; const Atext: PAnsiChar; const AposX: Int32; const AposY: Int32; const AfontSize: Int32; const Acolor: Color); external CLibName delayed;
procedure ImageDrawTextEx(const Adst: PImage; const Afont: Font; const Atext: PAnsiChar; const Aposition: Vector2; const AfontSize: Single; const Aspacing: Single; const Atint: Color); external CLibName delayed;
function  LoadTexture(const AfileName: PAnsiChar): Texture2D; external CLibName delayed;
function  LoadTextureFromImage(const Aimage: Image): Texture2D; external CLibName delayed;
function  LoadTextureCubemap(const Aimage: Image; const Alayout: Int32): TextureCubemap; external CLibName delayed;
function  LoadRenderTexture(const Awidth: Int32; const Aheight: Int32): RenderTexture2D; external CLibName delayed;
function  IsTextureValid(const Atexture: Texture2D): Boolean; external CLibName delayed;
procedure UnloadTexture(const Atexture: Texture2D); external CLibName delayed;
function  IsRenderTextureValid(const Atarget: RenderTexture2D): Boolean; external CLibName delayed;
procedure UnloadRenderTexture(const Atarget: RenderTexture2D); external CLibName delayed;
procedure UpdateTexture(const Atexture: Texture2D; const Apixels: Pointer); external CLibName delayed;
procedure UpdateTextureRec(const Atexture: Texture2D; const Arec: Rectangle; const Apixels: Pointer); external CLibName delayed;
procedure GenTextureMipmaps(const Atexture: PTexture2D); external CLibName delayed;
procedure SetTextureFilter(const Atexture: Texture2D; const Afilter: Int32); external CLibName delayed;
procedure SetTextureWrap(const Atexture: Texture2D; const Awrap: Int32); external CLibName delayed;
procedure DrawTexture(const Atexture: Texture2D; const AposX: Int32; const AposY: Int32; const Atint: Color); external CLibName delayed;
procedure DrawTextureV(const Atexture: Texture2D; const Aposition: Vector2; const Atint: Color); external CLibName delayed;
procedure DrawTextureEx(const Atexture: Texture2D; const Aposition: Vector2; const Arotation: Single; const Ascale: Single; const Atint: Color); external CLibName delayed;
procedure DrawTextureRec(const Atexture: Texture2D; const Asource: Rectangle; const Aposition: Vector2; const Atint: Color); external CLibName delayed;
procedure DrawTexturePro(const Atexture: Texture2D; const Asource: Rectangle; const Adest: Rectangle; const Aorigin: Vector2; const Arotation: Single; const Atint: Color); external CLibName delayed;
procedure DrawTextureNPatch(const Atexture: Texture2D; const AnPatchInfo: NPatchInfo; const Adest: Rectangle; const Aorigin: Vector2; const Arotation: Single; const Atint: Color); external CLibName delayed;
function  ColorIsEqual(const Acol1: Color; const Acol2: Color): Boolean; external CLibName delayed;
function  Fade(const Acolor: Color; const Aalpha: Single): Color; external CLibName delayed;
function  ColorToInt(const Acolor: Color): Int32; external CLibName delayed;
function  ColorNormalize(const Acolor: Color): Vector4; external CLibName delayed;
function  ColorFromNormalized(const Anormalized: Vector4): Color; external CLibName delayed;
function  ColorToHSV(const Acolor: Color): Vector3; external CLibName delayed;
function  ColorFromHSV(const Ahue: Single; const Asaturation: Single; const Avalue: Single): Color; external CLibName delayed;
function  ColorTint(const Acolor: Color; const Atint: Color): Color; external CLibName delayed;
function  ColorBrightness(const Acolor: Color; const Afactor: Single): Color; external CLibName delayed;
function  ColorContrast(const Acolor: Color; const Acontrast: Single): Color; external CLibName delayed;
function  ColorAlpha(const Acolor: Color; const Aalpha: Single): Color; external CLibName delayed;
function  ColorAlphaBlend(const Adst: Color; const Asrc: Color; const Atint: Color): Color; external CLibName delayed;
function  ColorLerp(const Acolor1: Color; const Acolor2: Color; const Afactor: Single): Color; external CLibName delayed;
function  GetColor(const AhexValue: UInt32): Color; external CLibName delayed;
function  GetPixelColor(const AsrcPtr: Pointer; const Aformat: Int32): Color; external CLibName delayed;
procedure SetPixelColor(const AdstPtr: Pointer; const Acolor: Color; const Aformat: Int32); external CLibName delayed;
function  GetPixelDataSize(const Awidth: Int32; const Aheight: Int32; const Aformat: Int32): Int32; external CLibName delayed;
function  GetFontDefault(): Font; external CLibName delayed;
function  LoadFont(const AfileName: PAnsiChar): Font; external CLibName delayed;
function  LoadFontEx(const AfileName: PAnsiChar; const AfontSize: Int32; const Acodepoints: Pointer; const AcodepointCount: Int32): Font; external CLibName delayed;
function  LoadFontFromImage(const Aimage: Image; const Akey: Color; const AfirstChar: Int32): Font; external CLibName delayed;
function  LoadFontFromMemory(const AfileType: PAnsiChar; const AfileData: PByte; const AdataSize: Int32; const AfontSize: Int32; const Acodepoints: Pointer; const AcodepointCount: Int32): Font; external CLibName delayed;
function  IsFontValid(const Afont: Font): Boolean; external CLibName delayed;
function  LoadFontData(const AfileData: PByte; const AdataSize: Int32; const AfontSize: Int32; const Acodepoints: Pointer; const AcodepointCount: Int32; const Atype: Int32): PGlyphInfo; external CLibName delayed;
function  GenImageFontAtlas(const Aglyphs: PGlyphInfo; const AglyphRecs: Pointer; const AglyphCount: Int32; const AfontSize: Int32; const Apadding: Int32; const ApackMethod: Int32): Image; external CLibName delayed;
procedure UnloadFontData(const Aglyphs: PGlyphInfo; const AglyphCount: Int32); external CLibName delayed;
procedure UnloadFont(const Afont: Font); external CLibName delayed;
function  ExportFontAsCode(const Afont: Font; const AfileName: PAnsiChar): Boolean; external CLibName delayed;
procedure DrawFPS(const AposX: Int32; const AposY: Int32); external CLibName delayed;
procedure DrawText(const Atext: PAnsiChar; const AposX: Int32; const AposY: Int32; const AfontSize: Int32; const Acolor: Color); external CLibName delayed;
procedure DrawTextEx(const Afont: Font; const Atext: PAnsiChar; const Aposition: Vector2; const AfontSize: Single; const Aspacing: Single; const Atint: Color); external CLibName delayed;
procedure DrawTextPro(const Afont: Font; const Atext: PAnsiChar; const Aposition: Vector2; const Aorigin: Vector2; const Arotation: Single; const AfontSize: Single; const Aspacing: Single; const Atint: Color); external CLibName delayed;
procedure DrawTextCodepoint(const Afont: Font; const Acodepoint: Int32; const Aposition: Vector2; const AfontSize: Single; const Atint: Color); external CLibName delayed;
procedure DrawTextCodepoints(const Afont: Font; const Acodepoints: Pointer; const AcodepointCount: Int32; const Aposition: Vector2; const AfontSize: Single; const Aspacing: Single; const Atint: Color); external CLibName delayed;
procedure SetTextLineSpacing(const Aspacing: Int32); external CLibName delayed;
function  MeasureText(const Atext: PAnsiChar; const AfontSize: Int32): Int32; external CLibName delayed;
function  MeasureTextEx(const Afont: Font; const Atext: PAnsiChar; const AfontSize: Single; const Aspacing: Single): Vector2; external CLibName delayed;
function  GetGlyphIndex(const Afont: Font; const Acodepoint: Int32): Int32; external CLibName delayed;
function  GetGlyphInfo(const Afont: Font; const Acodepoint: Int32): GlyphInfo; external CLibName delayed;
function  GetGlyphAtlasRec(const Afont: Font; const Acodepoint: Int32): Rectangle; external CLibName delayed;
function  LoadUTF8(const Acodepoints: Pointer; const Alength: Int32): PAnsiChar; external CLibName delayed;
procedure UnloadUTF8(const Atext: PAnsiChar); external CLibName delayed;
function  LoadCodepoints(const Atext: PAnsiChar; const Acount: Pointer): Pointer; external CLibName delayed;
procedure UnloadCodepoints(const Acodepoints: Pointer); external CLibName delayed;
function  GetCodepointCount(const Atext: PAnsiChar): Int32; external CLibName delayed;
function  GetCodepoint(const Atext: PAnsiChar; const AcodepointSize: Pointer): Int32; external CLibName delayed;
function  GetCodepointNext(const Atext: PAnsiChar; const AcodepointSize: Pointer): Int32; external CLibName delayed;
function  GetCodepointPrevious(const Atext: PAnsiChar; const AcodepointSize: Pointer): Int32; external CLibName delayed;
function  CodepointToUTF8(const Acodepoint: Int32; const Autf8Size: Pointer): PAnsiChar; external CLibName delayed;
function  TextCopy(const Adst: PAnsiChar; const Asrc: PAnsiChar): Int32; external CLibName delayed;
function  TextIsEqual(const Atext1: PAnsiChar; const Atext2: PAnsiChar): Boolean; external CLibName delayed;
function  TextLength(const Atext: PAnsiChar): UInt32; external CLibName delayed;
function  TextFormat(const Atext: PAnsiChar): PAnsiChar; varargs; external CLibName delayed;
function  TextSubtext(const Atext: PAnsiChar; const Aposition: Int32; const Alength: Int32): PAnsiChar; external CLibName delayed;
function  TextReplace(const Atext: PAnsiChar; const Areplace: PAnsiChar; const Aby: PAnsiChar): PAnsiChar; external CLibName delayed;
function  TextInsert(const Atext: PAnsiChar; const Ainsert: PAnsiChar; const Aposition: Int32): PAnsiChar; external CLibName delayed;
function  TextJoin(const AtextList: Pointer; const Acount: Int32; const Adelimiter: PAnsiChar): PAnsiChar; external CLibName delayed;
function  TextSplit(const Atext: PAnsiChar; const Adelimiter: AnsiChar; const Acount: Pointer): Pointer; external CLibName delayed;
procedure TextAppend(const Atext: PAnsiChar; const Aappend: PAnsiChar; const Aposition: Pointer); external CLibName delayed;
function  TextFindIndex(const Atext: PAnsiChar; const Afind: PAnsiChar): Int32; external CLibName delayed;
function  TextToUpper(const Atext: PAnsiChar): PAnsiChar; external CLibName delayed;
function  TextToLower(const Atext: PAnsiChar): PAnsiChar; external CLibName delayed;
function  TextToPascal(const Atext: PAnsiChar): PAnsiChar; external CLibName delayed;
function  TextToSnake(const Atext: PAnsiChar): PAnsiChar; external CLibName delayed;
function  TextToCamel(const Atext: PAnsiChar): PAnsiChar; external CLibName delayed;
function  TextToInteger(const Atext: PAnsiChar): Int32; external CLibName delayed;
function  TextToFloat(const Atext: PAnsiChar): Single; external CLibName delayed;
procedure DrawLine3D(const AstartPos: Vector3; const AendPos: Vector3; const Acolor: Color); external CLibName delayed;
procedure DrawPoint3D(const Aposition: Vector3; const Acolor: Color); external CLibName delayed;
procedure DrawCircle3D(const Acenter: Vector3; const Aradius: Single; const ArotationAxis: Vector3; const ArotationAngle: Single; const Acolor: Color); external CLibName delayed;
procedure DrawTriangle3D(const Av1: Vector3; const Av2: Vector3; const Av3: Vector3; const Acolor: Color); external CLibName delayed;
procedure DrawTriangleStrip3D(const Apoints: PVector3; const ApointCount: Int32; const Acolor: Color); external CLibName delayed;
procedure DrawCube(const Aposition: Vector3; const Awidth: Single; const Aheight: Single; const Alength: Single; const Acolor: Color); external CLibName delayed;
procedure DrawCubeV(const Aposition: Vector3; const Asize: Vector3; const Acolor: Color); external CLibName delayed;
procedure DrawCubeWires(const Aposition: Vector3; const Awidth: Single; const Aheight: Single; const Alength: Single; const Acolor: Color); external CLibName delayed;
procedure DrawCubeWiresV(const Aposition: Vector3; const Asize: Vector3; const Acolor: Color); external CLibName delayed;
procedure DrawSphere(const AcenterPos: Vector3; const Aradius: Single; const Acolor: Color); external CLibName delayed;
procedure DrawSphereEx(const AcenterPos: Vector3; const Aradius: Single; const Arings: Int32; const Aslices: Int32; const Acolor: Color); external CLibName delayed;
procedure DrawSphereWires(const AcenterPos: Vector3; const Aradius: Single; const Arings: Int32; const Aslices: Int32; const Acolor: Color); external CLibName delayed;
procedure DrawCylinder(const Aposition: Vector3; const AradiusTop: Single; const AradiusBottom: Single; const Aheight: Single; const Aslices: Int32; const Acolor: Color); external CLibName delayed;
procedure DrawCylinderEx(const AstartPos: Vector3; const AendPos: Vector3; const AstartRadius: Single; const AendRadius: Single; const Asides: Int32; const Acolor: Color); external CLibName delayed;
procedure DrawCylinderWires(const Aposition: Vector3; const AradiusTop: Single; const AradiusBottom: Single; const Aheight: Single; const Aslices: Int32; const Acolor: Color); external CLibName delayed;
procedure DrawCylinderWiresEx(const AstartPos: Vector3; const AendPos: Vector3; const AstartRadius: Single; const AendRadius: Single; const Asides: Int32; const Acolor: Color); external CLibName delayed;
procedure DrawCapsule(const AstartPos: Vector3; const AendPos: Vector3; const Aradius: Single; const Aslices: Int32; const Arings: Int32; const Acolor: Color); external CLibName delayed;
procedure DrawCapsuleWires(const AstartPos: Vector3; const AendPos: Vector3; const Aradius: Single; const Aslices: Int32; const Arings: Int32; const Acolor: Color); external CLibName delayed;
procedure DrawPlane(const AcenterPos: Vector3; const Asize: Vector2; const Acolor: Color); external CLibName delayed;
procedure DrawRay(const Aray: Ray; const Acolor: Color); external CLibName delayed;
procedure DrawGrid(const Aslices: Int32; const Aspacing: Single); external CLibName delayed;
function  LoadModel(const AfileName: PAnsiChar): Model; external CLibName delayed;
function  LoadModelFromMesh(const Amesh: Mesh): Model; external CLibName delayed;
function  IsModelValid(const Amodel: Model): Boolean; external CLibName delayed;
procedure UnloadModel(const Amodel: Model); external CLibName delayed;
function  GetModelBoundingBox(const Amodel: Model): BoundingBox; external CLibName delayed;
procedure DrawModel(const Amodel: Model; const Aposition: Vector3; const Ascale: Single; const Atint: Color); external CLibName delayed;
procedure DrawModelEx(const Amodel: Model; const Aposition: Vector3; const ArotationAxis: Vector3; const ArotationAngle: Single; const Ascale: Vector3; const Atint: Color); external CLibName delayed;
procedure DrawModelWires(const Amodel: Model; const Aposition: Vector3; const Ascale: Single; const Atint: Color); external CLibName delayed;
procedure DrawModelWiresEx(const Amodel: Model; const Aposition: Vector3; const ArotationAxis: Vector3; const ArotationAngle: Single; const Ascale: Vector3; const Atint: Color); external CLibName delayed;
procedure DrawModelPoints(const Amodel: Model; const Aposition: Vector3; const Ascale: Single; const Atint: Color); external CLibName delayed;
procedure DrawModelPointsEx(const Amodel: Model; const Aposition: Vector3; const ArotationAxis: Vector3; const ArotationAngle: Single; const Ascale: Vector3; const Atint: Color); external CLibName delayed;
procedure DrawBoundingBox(const Abox: BoundingBox; const Acolor: Color); external CLibName delayed;
procedure DrawBillboard(const Acamera: Camera; const Atexture: Texture2D; const Aposition: Vector3; const Ascale: Single; const Atint: Color); external CLibName delayed;
procedure DrawBillboardRec(const Acamera: Camera; const Atexture: Texture2D; const Asource: Rectangle; const Aposition: Vector3; const Asize: Vector2; const Atint: Color); external CLibName delayed;
procedure DrawBillboardPro(const Acamera: Camera; const Atexture: Texture2D; const Asource: Rectangle; const Aposition: Vector3; const Aup: Vector3; const Asize: Vector2; const Aorigin: Vector2; const Arotation: Single; const Atint: Color); external CLibName delayed;
procedure UploadMesh(const Amesh: PMesh; const Adynamic: Boolean); external CLibName delayed;
procedure UpdateMeshBuffer(const Amesh: Mesh; const Aindex: Int32; const Adata: Pointer; const AdataSize: Int32; const Aoffset: Int32); external CLibName delayed;
procedure UnloadMesh(const Amesh: Mesh); external CLibName delayed;
procedure DrawMesh(const Amesh: Mesh; const Amaterial: Material; const Atransform: Matrix); external CLibName delayed;
procedure DrawMeshInstanced(const Amesh: Mesh; const Amaterial: Material; const Atransforms: PMatrix; const Ainstances: Int32); external CLibName delayed;
function  GetMeshBoundingBox(const Amesh: Mesh): BoundingBox; external CLibName delayed;
procedure GenMeshTangents(const Amesh: PMesh); external CLibName delayed;
function  ExportMesh(const Amesh: Mesh; const AfileName: PAnsiChar): Boolean; external CLibName delayed;
function  ExportMeshAsCode(const Amesh: Mesh; const AfileName: PAnsiChar): Boolean; external CLibName delayed;
function  GenMeshPoly(const Asides: Int32; const Aradius: Single): Mesh; external CLibName delayed;
function  GenMeshPlane(const Awidth: Single; const Alength: Single; const AresX: Int32; const AresZ: Int32): Mesh; external CLibName delayed;
function  GenMeshCube(const Awidth: Single; const Aheight: Single; const Alength: Single): Mesh; external CLibName delayed;
function  GenMeshSphere(const Aradius: Single; const Arings: Int32; const Aslices: Int32): Mesh; external CLibName delayed;
function  GenMeshHemiSphere(const Aradius: Single; const Arings: Int32; const Aslices: Int32): Mesh; external CLibName delayed;
function  GenMeshCylinder(const Aradius: Single; const Aheight: Single; const Aslices: Int32): Mesh; external CLibName delayed;
function  GenMeshCone(const Aradius: Single; const Aheight: Single; const Aslices: Int32): Mesh; external CLibName delayed;
function  GenMeshTorus(const Aradius: Single; const Asize: Single; const AradSeg: Int32; const Asides: Int32): Mesh; external CLibName delayed;
function  GenMeshKnot(const Aradius: Single; const Asize: Single; const AradSeg: Int32; const Asides: Int32): Mesh; external CLibName delayed;
function  GenMeshHeightmap(const Aheightmap: Image; const Asize: Vector3): Mesh; external CLibName delayed;
function  GenMeshCubicmap(const Acubicmap: Image; const AcubeSize: Vector3): Mesh; external CLibName delayed;
function  LoadMaterials(const AfileName: PAnsiChar; const AmaterialCount: Pointer): PMaterial; external CLibName delayed;
function  LoadMaterialDefault(): Material; external CLibName delayed;
function  IsMaterialValid(const Amaterial: Material): Boolean; external CLibName delayed;
procedure UnloadMaterial(const Amaterial: Material); external CLibName delayed;
procedure SetMaterialTexture(const Amaterial: PMaterial; const AmapType: Int32; const Atexture: Texture2D); external CLibName delayed;
procedure SetModelMeshMaterial(const Amodel: PModel; const AmeshId: Int32; const AmaterialId: Int32); external CLibName delayed;
function  LoadModelAnimations(const AfileName: PAnsiChar; const AanimCount: Pointer): PModelAnimation; external CLibName delayed;
procedure UpdateModelAnimation(const Amodel: Model; const Aanim: ModelAnimation; const Aframe: Int32); external CLibName delayed;
procedure UpdateModelAnimationBones(const Amodel: Model; const Aanim: ModelAnimation; const Aframe: Int32); external CLibName delayed;
procedure UnloadModelAnimation(const Aanim: ModelAnimation); external CLibName delayed;
procedure UnloadModelAnimations(const Aanimations: PModelAnimation; const AanimCount: Int32); external CLibName delayed;
function  IsModelAnimationValid(const Amodel: Model; const Aanim: ModelAnimation): Boolean; external CLibName delayed;
function  CheckCollisionSpheres(const Acenter1: Vector3; const Aradius1: Single; const Acenter2: Vector3; const Aradius2: Single): Boolean; external CLibName delayed;
function  CheckCollisionBoxes(const Abox1: BoundingBox; const Abox2: BoundingBox): Boolean; external CLibName delayed;
function  CheckCollisionBoxSphere(const Abox: BoundingBox; const Acenter: Vector3; const Aradius: Single): Boolean; external CLibName delayed;
function  GetRayCollisionSphere(const Aray: Ray; const Acenter: Vector3; const Aradius: Single): RayCollision; external CLibName delayed;
function  GetRayCollisionBox(const Aray: Ray; const Abox: BoundingBox): RayCollision; external CLibName delayed;
function  GetRayCollisionMesh(const Aray: Ray; const Amesh: Mesh; const Atransform: Matrix): RayCollision; external CLibName delayed;
function  GetRayCollisionTriangle(const Aray: Ray; const Ap1: Vector3; const Ap2: Vector3; const Ap3: Vector3): RayCollision; external CLibName delayed;
function  GetRayCollisionQuad(const Aray: Ray; const Ap1: Vector3; const Ap2: Vector3; const Ap3: Vector3; const Ap4: Vector3): RayCollision; external CLibName delayed;
procedure InitAudioDevice(); external CLibName delayed;
procedure CloseAudioDevice(); external CLibName delayed;
function  IsAudioDeviceReady(): Boolean; external CLibName delayed;
procedure SetMasterVolume(const Avolume: Single); external CLibName delayed;
function  GetMasterVolume(): Single; external CLibName delayed;
function  LoadWave(const AfileName: PAnsiChar): Wave; external CLibName delayed;
function  LoadWaveFromMemory(const AfileType: PAnsiChar; const AfileData: PByte; const AdataSize: Int32): Wave; external CLibName delayed;
function  IsWaveValid(const Awave: Wave): Boolean; external CLibName delayed;
function  LoadSound(const AfileName: PAnsiChar): Sound; external CLibName delayed;
function  LoadSoundFromWave(const Awave: Wave): Sound; external CLibName delayed;
function  LoadSoundAlias(const Asource: Sound): Sound; external CLibName delayed;
function  IsSoundValid(const Asound: Sound): Boolean; external CLibName delayed;
procedure UpdateSound(const Asound: Sound; const Adata: Pointer; const AsampleCount: Int32); external CLibName delayed;
procedure UnloadWave(const Awave: Wave); external CLibName delayed;
procedure UnloadSound(const Asound: Sound); external CLibName delayed;
procedure UnloadSoundAlias(const Aalias: Sound); external CLibName delayed;
function  ExportWave(const Awave: Wave; const AfileName: PAnsiChar): Boolean; external CLibName delayed;
function  ExportWaveAsCode(const Awave: Wave; const AfileName: PAnsiChar): Boolean; external CLibName delayed;
procedure PlaySound(const Asound: Sound); external CLibName delayed;
procedure StopSound(const Asound: Sound); external CLibName delayed;
procedure PauseSound(const Asound: Sound); external CLibName delayed;
procedure ResumeSound(const Asound: Sound); external CLibName delayed;
function  IsSoundPlaying(const Asound: Sound): Boolean; external CLibName delayed;
procedure SetSoundVolume(const Asound: Sound; const Avolume: Single); external CLibName delayed;
procedure SetSoundPitch(const Asound: Sound; const Apitch: Single); external CLibName delayed;
procedure SetSoundPan(const Asound: Sound; const Apan: Single); external CLibName delayed;
function  WaveCopy(const Awave: Wave): Wave; external CLibName delayed;
procedure WaveCrop(const Awave: PWave; const AinitFrame: Int32; const AfinalFrame: Int32); external CLibName delayed;
procedure WaveFormat(const Awave: PWave; const AsampleRate: Int32; const AsampleSize: Int32; const Achannels: Int32); external CLibName delayed;
function  LoadWaveSamples(const Awave: Wave): Pointer; external CLibName delayed;
procedure UnloadWaveSamples(const Asamples: Pointer); external CLibName delayed;
function  LoadMusicStream(const AfileName: PAnsiChar): Music; external CLibName delayed;
function  LoadMusicStreamFromMemory(const AfileType: PAnsiChar; const Adata: PByte; const AdataSize: Int32): Music; external CLibName delayed;
function  IsMusicValid(const Amusic: Music): Boolean; external CLibName delayed;
procedure UnloadMusicStream(const Amusic: Music); external CLibName delayed;
procedure PlayMusicStream(const Amusic: Music); external CLibName delayed;
function  IsMusicStreamPlaying(const Amusic: Music): Boolean; external CLibName delayed;
procedure UpdateMusicStream(const Amusic: Music); external CLibName delayed;
procedure StopMusicStream(const Amusic: Music); external CLibName delayed;
procedure PauseMusicStream(const Amusic: Music); external CLibName delayed;
procedure ResumeMusicStream(const Amusic: Music); external CLibName delayed;
procedure SeekMusicStream(const Amusic: Music; const Aposition: Single); external CLibName delayed;
procedure SetMusicVolume(const Amusic: Music; const Avolume: Single); external CLibName delayed;
procedure SetMusicPitch(const Amusic: Music; const Apitch: Single); external CLibName delayed;
procedure SetMusicPan(const Amusic: Music; const Apan: Single); external CLibName delayed;
function  GetMusicTimeLength(const Amusic: Music): Single; external CLibName delayed;
function  GetMusicTimePlayed(const Amusic: Music): Single; external CLibName delayed;
function  LoadAudioStream(const AsampleRate: UInt32; const AsampleSize: UInt32; const Achannels: UInt32): AudioStream; external CLibName delayed;
function  IsAudioStreamValid(const Astream: AudioStream): Boolean; external CLibName delayed;
procedure UnloadAudioStream(const Astream: AudioStream); external CLibName delayed;
procedure UpdateAudioStream(const Astream: AudioStream; const Adata: Pointer; const AframeCount: Int32); external CLibName delayed;
function  IsAudioStreamProcessed(const Astream: AudioStream): Boolean; external CLibName delayed;
procedure PlayAudioStream(const Astream: AudioStream); external CLibName delayed;
procedure PauseAudioStream(const Astream: AudioStream); external CLibName delayed;
procedure ResumeAudioStream(const Astream: AudioStream); external CLibName delayed;
function  IsAudioStreamPlaying(const Astream: AudioStream): Boolean; external CLibName delayed;
procedure StopAudioStream(const Astream: AudioStream); external CLibName delayed;
procedure SetAudioStreamVolume(const Astream: AudioStream; const Avolume: Single); external CLibName delayed;
procedure SetAudioStreamPitch(const Astream: AudioStream; const Apitch: Single); external CLibName delayed;
procedure SetAudioStreamPan(const Astream: AudioStream; const Apan: Single); external CLibName delayed;
procedure SetAudioStreamBufferSizeDefault(const Asize: Int32); external CLibName delayed;
procedure SetAudioStreamCallback(const Astream: AudioStream; const Acallback: AudioCallback); external CLibName delayed;
procedure AttachAudioStreamProcessor(const Astream: AudioStream; const Aprocessor: AudioCallback); external CLibName delayed;
procedure DetachAudioStreamProcessor(const Astream: AudioStream; const Aprocessor: AudioCallback); external CLibName delayed;
procedure AttachAudioMixedProcessor(const Aprocessor: AudioCallback); external CLibName delayed;
procedure DetachAudioMixedProcessor(const Aprocessor: AudioCallback); external CLibName delayed;

implementation

end.
