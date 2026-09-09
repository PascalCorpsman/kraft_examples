(******************************************************************************)
(*                                                                            *)
(* Author      : Uwe Schächterle (Corpsman)                                   *)
(*                                                                            *)
(* This file is part of Kraft examples                                        *)
(*                                                                            *)
(*  See the file license.md, located under:                                   *)
(*  https://github.com/PascalCorpsman/Software_Licenses/blob/main/license.md  *)
(*  for details about the license.                                            *)
(*                                                                            *)
(*               It is not allowed to change or remove this text from any     *)
(*               source file of the project.                                  *)
(*                                                                            *)
(******************************************************************************)
Unit helpers;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, kraft, uvectormath, dglOpenGL, OpenGLContext;

Type

  TObjectProcedure = Procedure() Of Object;

  { TDummy }

  TDummy = Class
  public
    OpenGLControl: TOpenGLControl;
    Initialized: PBoolean;
    OnResize: TNotifyEvent;
    Invalidate: TObjectProcedure;

    Procedure OpenGLControl1MakeCurrent(Sender: TObject; Var Allow: boolean);
    Procedure FormDestroy(Sender: TObject);
    Procedure OpenGLControl1Resize(Sender: TObject);
  End;

Operator := (v: TKraftVector3): TVector3;

Procedure SetCameraTransform(Const Width, Height: integer; Const Eye, Center, Up: TVector3);
Procedure RenderLineLoop3D(Const Points: Array Of TVector3; Const Color: TVector3);

Var
  ShaderProgram: GLuint;
  VAO: GLuint = 0; // Vertex Array Object
  VBO: GLuint = 0; // Vertex Buffer Object

  Dummy: TDummy;

Implementation

Uses
  Math, Dialogs;

Operator := (v: TKraftVector3): TVector3;
Begin
  result.x := v.x;
  result.y := v.y;
  result.z := v.z;
End;

Const
  VertexSrc: PChar =
  '#version 330 core'#10 +
    'layout(location = 0) in vec3 aPos;'#10 +
    'uniform mat4 uTransform;'#10 +
    'void main() {'#10 +
    '  gl_Position = uTransform * vec4(aPos, 1.0);'#10 +
    '}';

  FragmentSrc: PChar =
  '#version 330 core'#10 +
    'uniform vec3 uColor;'#10 +
    'out vec4 FragColor;'#10 +
    'void main() {'#10 +
    '  FragColor = vec4(uColor, 1.0);'#10 +
    '}';

Function CompileShader(Src: PChar; ShaderType: GLenum): GLuint;
Var
  S: GLuint;
  status: GLint;
  Log: Array[0..1023] Of char;
Begin
  result := 0;
  S := glCreateShader(ShaderType);
  glShaderSource(S, 1, @Src, Nil);
  glCompileShader(S);

  glGetShaderiv(S, GL_COMPILE_STATUS, @status);
  If status = 0 Then Begin
    glGetShaderInfoLog(S, 1024, Nil, @Log);
    Raise Exception.Create('Shader Fehler: ' + Log);
  End;

  Result := S;
End;

Function CreateShaderProgram: GLuint;
Var
  vs, fs: GLuint;
  prog: GLuint;
  status: GLint;
  Log: Array[0..1023] Of char;
Begin
  vs := CompileShader(VertexSrc, GL_VERTEX_SHADER);
  fs := CompileShader(FragmentSrc, GL_FRAGMENT_SHADER);

  prog := glCreateProgram();
  glAttachShader(prog, vs);
  glAttachShader(prog, fs);
  glLinkProgram(prog);

  glGetProgramiv(prog, GL_LINK_STATUS, @status);
  If status = 0 Then Begin
    glGetProgramInfoLog(prog, 1024, Nil, @Log);
    Raise Exception.Create('Link Fehler: ' + Log);
  End;

  glDeleteShader(vs);
  glDeleteShader(fs);

  Result := prog;
End;

// Replaces gluLookAt plus gluPerspective for the shader path.

Procedure SetCameraTransform(Const Width, Height: integer; Const Eye, Center,
  Up: TVector3);
Const
  NearPlane = 0.1;
  FarPlane = 100;
Var
  Forward, Right, CameraUp: TVector3;
  View, Projection, Transform: TMatrix4x4;
  Aspect, FocalLength: GLfloat;
  TransformLocation: GLint;
Begin
  Forward := NormV3(SubV3(Center, Eye));
  Right := NormV3(CrossV3(Forward, Up));
  CameraUp := CrossV3(Right, Forward);

  // Matrices are stored column-major, as OpenGL expects them with GL_FALSE.
  View[0, 0] := Right.x;
  View[0, 1] := CameraUp.x;
  View[0, 2] := -Forward.x;
  View[0, 3] := 0;
  View[1, 0] := Right.y;
  View[1, 1] := CameraUp.y;
  View[1, 2] := -Forward.y;
  View[1, 3] := 0;
  View[2, 0] := Right.z;
  View[2, 1] := CameraUp.z;
  View[2, 2] := -Forward.z;
  View[2, 3] := 0;
  View[3, 0] := -DotV3(Right, Eye);
  View[3, 1] := -DotV3(CameraUp, Eye);
  View[3, 2] := DotV3(Forward, Eye);
  View[3, 3] := 1;

  Aspect := Width / Height;
  FocalLength := 1 / Tan(DegToRad(45) / 2);
  Projection[0, 0] := FocalLength / Aspect;
  Projection[0, 1] := 0;
  Projection[0, 2] := 0;
  Projection[0, 3] := 0;
  Projection[1, 1] := 0;
  Projection[1, 1] := FocalLength;
  Projection[1, 2] := 0;
  Projection[1, 3] := 0;
  Projection[2, 0] := 0;
  Projection[2, 1] := 0;
  Projection[2, 2] := (FarPlane + NearPlane) / (NearPlane - FarPlane);
  Projection[2, 3] := -1;
  Projection[3, 0] := 0;
  Projection[3, 1] := 0;
  Projection[3, 2] := 2 * FarPlane * NearPlane / (NearPlane - FarPlane);
  Projection[3, 3] := 0;
  Transform := Projection * View;

  TransformLocation := glGetUniformLocation(ShaderProgram, 'uTransform');
  If TransformLocation >= 0 Then
    glUniformMatrix4fv(TransformLocation, 1, GL_FALSE, @Transform[0, 0]);
End;

Procedure RenderLineLoop3D(Const Points: Array Of TVector3; Const Color: TVector3);
Var
  VertexData: Array Of GLfloat;
  Index, ColorLocation: Integer;
Begin
  If Length(Points) < 2 Then Exit;

  SetLength(VertexData, Length(Points) * 3);
  For Index := 0 To High(Points) Do Begin
    VertexData[Index * 3] := Points[Index].x;
    VertexData[Index * 3 + 1] := Points[Index].y;
    VertexData[Index * 3 + 2] := Points[Index].z;
  End;

  ColorLocation := glGetUniformLocation(ShaderProgram, 'uColor');
  If ColorLocation >= 0 Then
    glUniform3f(ColorLocation, Color.x, Color.y, Color.z);

  glBindVertexArray(VAO);
  glBindBuffer(GL_ARRAY_BUFFER, VBO);
  glBufferData(GL_ARRAY_BUFFER, Length(VertexData) * SizeOf(GLfloat), @VertexData[0], GL_DYNAMIC_DRAW);
  glEnableVertexAttribArray(0);
  glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, Nil);
  glDrawArrays(GL_LINE_LOOP, 0, Length(Points));
  glDisableVertexAttribArray(0);
  glBindVertexArray(0);
End;

{ TDummy }

Var
  allowcnt: Integer = 0;

Procedure TDummy.OpenGLControl1MakeCurrent(Sender: TObject; Var Allow: boolean);
Begin
  If allowcnt > 2 Then Begin
    exit;
  End;
  inc(allowcnt);
  // Sollen Dialoge beim Starten ausgeführt werden ist hier der Richtige Zeitpunkt
  If allowcnt = 1 Then Begin
    // Init dglOpenGL.pas , Teil 2
    ReadExtensions; // Anstatt der Extentions kann auch nur der Core geladen werden. ReadOpenGLCore;
    ReadImplementationProperties;
  End;
  If allowcnt = 2 Then Begin // Dieses If Sorgt mit dem obigen dafür, dass der Code nur 1 mal ausgeführt wird.

{$IFNDEF LEGACYMODE}
    If Not Assigned(glCreateShader) Then Begin
      // On Windows it seems that you need to "reload" the core functions for proper function
      ReadExtensions;
      ReadImplementationProperties;
      // if still not available, then halt
      If Not Assigned(glCreateShader) Then Begin
        showmessage('glCreateShader not available, use legacy mode..');
        halt;
      End;
    End;
    ShaderProgram := CreateShaderProgram;
    glGenVertexArrays(1, @VAO);
    glGenBuffers(1, @VBO);
{$ENDIF}
    // Der Anwendung erlauben zu Rendern.
    dummy.Initialized^ := True;
    dummy.OnResize(Nil);
  End;
  dummy.Invalidate;
End;

Procedure TDummy.FormDestroy(Sender: TObject);
Begin
  If Initialized^ And OpenGLControl.MakeCurrent Then Begin
    If ShaderProgram <> 0 Then
      glDeleteProgram(ShaderProgram);
    If VAO <> 0 Then
      glDeleteVertexArrays(1, @VAO);
    If VBO <> 0 Then
      glDeleteBuffers(1, @VBO);
  End;
End;

Procedure TDummy.OpenGLControl1Resize(Sender: TObject);
Begin
  If Initialized^ Then Begin
    If OpenGLControl.MakeCurrent Then
      glViewport(0, 0, OpenGLControl.Width, OpenGLControl.Height);
    OpenGLControl.Invalidate;
  End;
End;


Initialization
  dummy := TDummy.Create;

Finalization
  dummy.free;

End.

