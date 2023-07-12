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

Unit Unit1;

{$MODE objfpc}{$H+}
{$DEFINE DebuggMode}

Interface

Uses
  Classes, SysUtils, FileUtil, LResources, Forms, Controls, Graphics, Dialogs,
  ExtCtrls, StdCtrls,
  OpenGlcontext,
  (*
   * Kommt ein Linkerfehler wegen OpenGL dann: sudo apt-get install freeglut3-dev
   *)
  dglOpenGL // http://wiki.delphigl.com/index.php/dglOpenGL.pas
  , kraft // Include the Kraft Physics Engine
  ;

Type

  { TForm1 }

  TForm1 = Class(TForm)
    Button1: TButton;
    CheckBox1: TCheckBox;
    CheckBox2: TCheckBox;
    OpenGLControl1: TOpenGLControl;
    ScrollBar1: TScrollBar;
    Timer1: TTimer;
    Procedure Button1Click(Sender: TObject);
    Procedure CheckBox1Click(Sender: TObject);
    Procedure CheckBox2Click(Sender: TObject);
    Procedure FormCloseQuery(Sender: TObject; Var CanClose: Boolean);
    Procedure FormCreate(Sender: TObject);
    Procedure OpenGLControl1MakeCurrent(Sender: TObject; Var Allow: boolean);
    Procedure OpenGLControl1Paint(Sender: TObject);
    Procedure OpenGLControl1Resize(Sender: TObject);
    Procedure ScrollBar1Change(Sender: TObject);
    Procedure Timer1Timer(Sender: TObject);
  private
    { private declarations }

    KraftWorld: TKraft; // Instance of the Kraft Physic Engine

    CompoundBox: TKraftRigidBody; // Keeping a local variable of a element is only necessary if you want to interfere with that object during emulation

    LastTick: uint64; // Used to do Time Simulation

    Procedure CreateWorld;

    Procedure ClearWorldContent; // As we use userdata we have to "clear" the userdata to prevent memory leaks

    Procedure RenderSzene;

    Procedure UpdatePhysics;
  public
    { public declarations }
  End;

Var
  Form1: TForm1;

  Initialized: Boolean = false; // Wenn True dann ist OpenGL initialisiert

Implementation

{$R *.lfm}

Const
  (*
   * Its used in create and reset, so therefore provide it as a constant
   *)
  MoveableBoxStartingPosition: TKraftVector3 = (X: 1.5; y: 3; Z: 0; W: 0); // W will show is the Vector is a direction (=1) or a absolute value (=0)

  { TForm1 }

Procedure TForm1.FormCreate(Sender: TObject);
Begin
  // Init dglOpenGL.pas , Teil 1
  If Not InitOpenGl Then Begin
    showmessage('Error, could not init dglOpenGL.pas');
    Halt;
  End;
  (*
  60 - FPS entsprechen
  0.01666666 ms
  Ist Interval auf 16 hängt das gesamte system, bei 17 nicht.
  Generell sollte die Interval Zahl also dynamisch zum Rechenaufwand, mindestens aber immer 17 sein.
  *)
  Timer1.Interval := 17;

  KraftWorld := TKraft.Create(-1); // Create engine in Single Threaded mode
  KraftWorld.WorldFrequency := 60; // We want the Engine to run at 60 FPS (default)
  KraftWorld.Gravity.Vector := Vector3(0, -9.8, 0); // (default)
  CreateWorld;
End;

Procedure TForm1.FormCloseQuery(Sender: TObject; Var CanClose: Boolean);
Begin
  Timer1.Enabled := false;
  Initialized := false;
  ClearWorldContent; // This is optional, as the World will free everyting by itself
  KraftWorld.Free;
End;

Procedure TForm1.ClearWorldContent;
Begin
  // TODO: is there more which needs to be freed ?
  While assigned(KraftWorld.RigidBodyFirst) Do Begin
    KraftWorld.RigidBodyFirst.Free;
  End;

  While assigned(KraftWorld.ConstraintFirst) Do Begin // Actually in this demo not used.
    KraftWorld.ConstraintFirst.Free;
  End;
End;

Procedure TForm1.RenderSzene;
Var
  RigidBody: TKraftRigidBody;
  Shape: TKraftShape;
  ShapeHull: TKraftShapeConvexHull;
  i: Integer;
  v: TKraftVector3;
Begin
  // This will render the "Floor", this is kind of redundant, as the floor is also part
  // of the world but as the world floor is a plane its dimensions are to big to see
  // something by the Rigid Body rendering below, so it is rendered here.
  // Keep in mind that the Flor shape has a quit bigger dimension than the "visual" will
  // show here.
  glcolor3f(1, 0, 0);
  glbegin(GL_QUADS);
  glvertex3f(-100, 0, 100);
  glvertex3f(-100, 0, -100);
  glvertex3f(100, 0, -100);
  glvertex3f(100, 0, 100);
  glend();
  // Iterate through each Body (also the floor)
  RigidBody := KraftWorld.RigidBodyFirst;
  While assigned(RigidBody) Do Begin
    glPushMatrix;
    // Dynamic Objects will be rendered in Yellow
    If RigidBody.IsDynamic Then Begin
      glcolor3f(1, 1, 0);
    End
    Else Begin
      // Static Objects will be rendered in white ;)
      glcolor3f(1, 1, 1);
    End;
    // Get the bodys rotation and Position matrix and multiply it onto the Modelview matrix
    glMultMatrixf(@RigidBody.WorldTransform[0, 0]);
    // Iterate through each Shape thats the Body consist of
    Shape := RigidBody.ShapeFirst;
    While assigned(Shape) Do Begin
      If shape Is TKraftShapeConvexHull Then Begin
        glPushMatrix;
        ShapeHull := TKraftShapeConvexHull(shape);
        glMultMatrixf(@ShapeHull.LocalTransform[0, 0]);
        // This is the acutal rendering of the Points of the shape
        glbegin(GL_LINE_LOOP);
        For i := 0 To ShapeHull.ConvexHull.CountVertices - 1 Do Begin
          v := ShapeHull.ConvexHull.Vertices[i].Position;
          // Aktually v holds 4 singles, only 3 are needed, as the
          // glvertex3fv reads in only the first 3, and they are stored
          // in the requested correct order x,y,z everything is fine.
          glvertex3fv(@v);
        End;
        glend();
        glPopMatrix;
      End;
      Shape := Shape.ShapeNext;
    End;
    glPopMatrix;
    // Switch to the next Rigidbody in the world
    RigidBody := RigidBody.RigidBodyNext;
  End;
  // Render The Center of Mass of our Compound Body
  glPushMatrix;
  glMultMatrixf(@CompoundBox.WorldTransform[0, 0]);
  glPointSize(5);
  glColor3f(0, 0, 1);
  glBegin(GL_POINTS);
  v := CompoundBox.ForcedCenterOfMass.Vector;
  glvertex3fv(@v);
  glend;
  glPointSize(5);
  glPopMatrix;
End;

Procedure TForm1.CreateWorld;
Var
  RigidBody: TKraftRigidBody;
  Shape: TKraftShape;
  Floor: TKraftRigidBody;
  FloorShape: TKraftShapePlane; // A Plane infinite in width
Begin
  (*
   * Each element in the Physiks Engine is a TKraftRigidBody
   * it can consists of multiple shapes.
   * A Shape is a container vor a hull and connects the Body with the hull ?
   *)
  // 1. Floor Creation
  Floor := TKraftRigidBody.Create(KraftWorld);
  Floor.SetRigidBodyType(krbtSTATIC);
  // Planes are defined by their normal vector and distance to the Origin.
  FloorShape := TKraftShapePlane.Create(KraftWorld, Floor, Plane(Vector3Norm(Vector3(0.0, 1.0, 0.0)), 0.0));
  FloorShape.Restitution := 0.3; // TODO: Why, it is static ?
  FloorShape.Density := 1.0; // TODO: Why, it is static ?
  Floor.ForcedMass := 0.01; // TODO: Why, it is static ?
  Floor.Finish;
  // Move the Floor plane to the Needed position ;)
  Floor.SetWorldTransformation(Matrix4x4Translate(0.0, 0.0, 0.0));
  (*
   * There are multiple ways to create a Box, this demo shows 2 different ways
   *)
  RigidBody := TKraftRigidBody.Create(KraftWorld);
  RigidBody.SetRigidBodyType(krbtSTATIC); // Init as static Object
  (*
   * Lets form a ****
   *                *
   *                *
   *                *
   *                * structure
   *)
  shape := TKraftShapeBox.Create(KraftWorld, RigidBody, Vector3(0.5, 2, 0.5));
  Shape.Restitution := 0.3;
  Shape.Density := 1.0;
  Shape.LocalTransform := Matrix4x4Translate(0, 2, 0);
  Shape.SynchronizeTransform;
  Shape.Finish;
  shape := TKraftShapeBox.Create(KraftWorld, RigidBody, Vector3(2, 0.5, 0.5));
  Shape.Restitution := 0.3;
  Shape.Density := 1.0;
  Shape.LocalTransform := Matrix4x4Translate(1.5, 4.5, 0);
  Shape.Finish;
  RigidBody.ForcedMass := 10;
  RigidBody.Finish;
  RigidBody.SetWorldPosition(MoveableBoxStartingPosition);

  CompoundBox := RigidBody;
  ScrollBar1.OnChange(Nil);
End;

Procedure TForm1.UpdatePhysics;
Var
  cnt, NewTick, Delta: uint64;
Begin
  If Not CheckBox1.Checked Then exit; // Is time evaluation enabled ?
  // Calculate time since last update -> delta
  NewTick := GetTickCount64;
  delta := NewTick - LastTick;
  (*
    Don't do this !

    KraftWorld.Step(delta / 1000);

    In terms of accuracy, it is acually better to always use the same deltatime.

    So we call the Engine Step function as often as needed to simulate the given delta time.
   *)
  cnt := 1; // if delta is to short, we do not call the step function at all !
  While cnt * KraftWorld.WorldDeltaTime * 1000 < delta Do Begin
    KraftWorld.Step(); // Actually let the engine do its work
    inc(cnt);
  End;
  // Last thing accumulate the simulated time.
  LastTick := LastTick + trunc((cnt - 1) * KraftWorld.WorldDeltaTime * 1000);
End;

Procedure TForm1.OpenGLControl1Paint(Sender: TObject);
Begin
  If Not Initialized Then Exit;
  // Clear all Render Buffers
  glClearColor(0.0, 0.0, 0.0, 0.0);
  glClear(GL_COLOR_BUFFER_BIT Or GL_DEPTH_BUFFER_BIT);
  glLoadIdentity();
  // Move the Viewpoint a little, so that we can see whats going on
  gluLookAt(5, 11, -20, 5, 5, 0, 0, 1, 0);
  // Give the Physics Engine time to do it's things..
  UpdatePhysics;
  // Render the updated world
  RenderSzene;
  // Make the updates visible to the screen
  OpenGLControl1.SwapBuffers;
End;

Procedure TForm1.CheckBox1Click(Sender: TObject);
Begin
  // start "Timing", if needed
  If CheckBox1.Checked Then Begin
    // Reset last Time calculated to be not "Glithy" when starting
    LastTick := GetTickCount64;
  End;
End;

Procedure TForm1.CheckBox2Click(Sender: TObject);
Begin
  // Set / not Set Moving of Box
  If CheckBox2.Checked Then Begin
    CompoundBox.ForcedMass := 1;
    (*
     * Set the Body to moveable
     *)
    // TODO: What is the difference between Kinematic and Dynamic ?
    CompoundBox.SetRigidBodyType(krbtDynamic); // krbtKinematic ??
    CompoundBox.Finish; //
    // TODO: What is this routine for ? box.SetToAwake; // Maybe a already "moving" element that lays down still needs to be SetAwake that it can move again ?
  End
  Else Begin
    CompoundBox.SetRigidBodyType(krbtSTATIC);
    // If you also want to reset Rotation / Inertia and all that other stuff, see "reset" button code.
  End;
End;


Procedure TForm1.Button1Click(Sender: TObject);
Begin
  // Reset
  (*
   * Normaly you expect to reset the WorldTransform as this holds every Rotation, Position ..
   * Information, but it seems that the Engine does not update orientation if you "override" the
   * WorldTransform Matrix, so instead we set the Orientation to zero and then reset the position
   * through the SetWorldPosition method
   *)
  //CompoundBox.WorldTransform := Matrix4x4Identity; //<-- This wont't work
  CompoundBox.SetOrientation(0, 0, 0);
  CompoundBox.SetWorldPosition(MoveableBoxStartingPosition);

  // Also reset all inertias to really get the same behavior as on "start"
  CompoundBox.LinearVelocity := Vector3(0, 0, 0);
  CompoundBox.AngularVelocity := Vector3(0, 0, 0);
End;

Var
  allowcnt: Integer = 0;

Procedure TForm1.OpenGLControl1MakeCurrent(Sender: TObject; Var Allow: boolean);
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
    // Der Anwendung erlauben zu Rendern.
    Initialized := True;
    // glEnable(GL_DEPTH_TEST); -- Debug only
    OpenGLControl1Resize(Nil);
  End;
  Form1.Invalidate;
End;

Procedure TForm1.OpenGLControl1Resize(Sender: TObject);
Begin
  If Initialized Then Begin
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glViewport(0, 0, OpenGLControl1.Width, OpenGLControl1.Height);
    gluPerspective(45.0, OpenGLControl1.Width / OpenGLControl1.Height, 0.1, 100.0);
    glMatrixMode(GL_MODELVIEW);
  End;
End;

Procedure TForm1.ScrollBar1Change(Sender: TObject);
Begin
  (*
   * Set a new Center of Mass
   *)
  CompoundBox.ForcedCenterOfMass.Vector := Vector3(ScrollBar1.Position / 50 + 1.5, 4.5, 0);
  // Set the Physics Engine to use the given Centre of Mass and do not auto calc it by the shapes !
  CompoundBox.Flags := CompoundBox.Flags + [krbfHasForcedCenterOfMass];

  Why does the object more or less "explode" if it starts to fall over ?

End;

Procedure TForm1.Timer1Timer(Sender: TObject);
{$IFDEF DebuggMode}
Var
  i: Cardinal;
  p: Pchar;
{$ENDIF}
Begin
  If Initialized Then Begin
    OpenGLControl1.Invalidate;
{$IFDEF DebuggMode}
    i := glGetError();
    If i <> 0 Then Begin
      Timer1.Enabled := false;
      p := gluErrorString(i);
      showmessage('OpenGL Error (' + inttostr(i) + ') occured.' + LineEnding + LineEnding +
        'OpenGL Message : "' + p + '"' + LineEnding + LineEnding +
        'Applikation will be terminated.');
      close;
    End;
{$ENDIF}
  End;
End;

End.

