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
    Button2: TButton;
    CheckBox1: TCheckBox;
    CheckBox2: TCheckBox;
    OpenGLControl1: TOpenGLControl;
    Timer1: TTimer;
    Procedure Button2Click(Sender: TObject);
    Procedure CheckBox1Click(Sender: TObject);
    Procedure CheckBox2Click(Sender: TObject);
    Procedure FormCloseQuery(Sender: TObject; Var CanClose: Boolean);
    Procedure FormCreate(Sender: TObject);
    Procedure OpenGLControl1MakeCurrent(Sender: TObject; Var Allow: boolean);
    Procedure OpenGLControl1Paint(Sender: TObject);
    Procedure OpenGLControl1Resize(Sender: TObject);
    Procedure Timer1Timer(Sender: TObject);
  private
    { private declarations }

    KraftWorld: TKraft; // Instance of the Kraft Physic Engine

    Box: TKraftRigidBody; // Keeping a local variable of a element is only necessary if you want to interfere with that object during emulation

    LastTick: uint64; // Used to do Time Simulation

    Procedure CreateWorld;

    Procedure ClearWorldContent; // Use only if you want to empty the world's content without freeing the KraftWorld instance

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

  // Render Every Rigid Body that is in the world as "Looped Line"
  glcolor3f(1, 1, 1);
  // Iterate through each Body (also the floor)
  RigidBody := KraftWorld.RigidBodyFirst;
  While assigned(RigidBody) Do Begin
    glPushMatrix;
    // Get the bodys rotation and Position matrix and multiply it onto the Modelview matrix
    glMultMatrixf(@RigidBody.WorldTransform[0, 0]);
    // Iterate through each Shape thats the Body consist of
    Shape := RigidBody.ShapeFirst;
    While assigned(Shape) Do Begin
      If shape Is TKraftShapeConvexHull Then Begin
        ShapeHull := TKraftShapeConvexHull(shape);
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
      End;
      Shape := Shape.ShapeNext;
    End;
    glPopMatrix;
    // Switch to the next Rigidbody in the world
    RigidBody := RigidBody.RigidBodyNext;
  End;
End;

Procedure TForm1.CreateWorld;
Var
  RigidBody: TKraftRigidBody;
  Hull: TKraftConvexHull;
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
  //
  Floor.CollisionGroups := [0]; // TODO: How do Collision Groups work ??

  (*
   * There are multiple ways to create a Box, this demo shows 2 different ways
   *)
  // 1. by Creating a convex Hull out of vertices
  // A Box with dimension(2,1,2) defined by its vertices and stored in a Convex Hull
  Hull := TKraftConvexHull.Create(KraftWorld);
  hull.AddVertex(Vector3(-1, -0.5, 1));
  hull.AddVertex(Vector3(-1, -0.5, -1));
  hull.AddVertex(Vector3(1, -0.5, -1));
  hull.AddVertex(Vector3(1, -0.5, 1));
  hull.AddVertex(Vector3(-1, 0.5, 1));
  hull.AddVertex(Vector3(-1, 0.5, -1));
  hull.AddVertex(Vector3(1, 0.5, -1));
  hull.AddVertex(Vector3(1, 0.5, 1));
  hull.Build();
  hull.Finish;

  // Create a Box that later can be moveable
  RigidBody := TKraftRigidBody.Create(KraftWorld);
  RigidBody.SetRigidBodyType(krbtSTATIC); // Init as static Object
  Shape := TKraftShapeConvexHull.Create(KraftWorld, RigidBody, hull);
  // TODO: How does ForcedMass, Restitution and Density interact with each oder ? and why are some defined at shape level and others on rigidbody level ?
  Shape.Restitution := 0.3;
  Shape.Density := 1.0;
  RigidBody.ForcedMass := 10;
  RigidBody.Finish;
  (*
   * You can set a rigidbodys position via the World transform Matrix
   *)
  //RigidBody.SetWorldTransformation(Matrix4x4Translate(MoveableBoxStartingPosition));
  (*
   * or by the SetWorldPosition method
   *)
  RigidBody.SetWorldPosition(MoveableBoxStartingPosition);
  RigidBody.CollisionGroups := [0]; // TODO: How do Collision Groups work ??
  Floor.UserData := Nil; // Attach user data to the object if needed ;)
  (*
   * If Needed you can set a own gravity for the box, otherwise the worlds gravity is used.
   * )
  RigidBody.Flags := RigidBody.Flags + [TKraftRigidBodyFlag.krbfHasOwnGravity];
  RigidBody.Gravity.x := 9.8;
  RigidBody.Gravity.y := 0.0;
  RigidBody.Gravity.z := 0.0;
  // *)

  // Store the Rigid Body's variable in a global Variable to be able to access it later
  Box := RigidBody;

  // 2. Create a Box by a default shape
  // Create a box that stands on the floor so that we have something to fall against
  RigidBody := TKraftRigidBody.Create(KraftWorld);
  RigidBody.SetRigidBodyType(krbtSTATIC);
  (*
   * we can either reuse the above created hull (as it did not change)
   *)
  //Shape := TKraftShapeConvexHull.Create(KraftWorld, RigidBody, hull);
  (*
   * or create the box by a default shape (Sphere, Capsule, ConvexHull, Box, Plane, Mesh)
   *)
  // TODO: wtf no Cone, Cylinder ?
  // TODO: is this a Bug, in the orig Code, i would expect that a box with extends 2,1,2 is of dimension 2,1,2. But actually it is 4,2,4
  Shape := TKraftShapeBox.Create(KraftWorld, RigidBody, vector3(2 / 2, 1 / 2, 2 / 2));
  // TODO: How does ForcedMass, Restitution and Density interact with each oder ? and why are some defined at shape level and others on rigidbody level ?
  Shape.Restitution := 0.3;
  Shape.Density := 1.0;
  RigidBody.ForcedMass := 1;
  RigidBody.Finish;
  // As the Shape is symetric to its origin, we have to sets the Body Position a little bit "up"
  // to set it flat on the ground
  RigidBody.SetWorldPosition(vector3(0, 0.5, 0));
  RigidBody.CollisionGroups := [0]; // TODO: How do Collision Groups work ??

  //Create Aufräumen,
   //Dann noch nen Collider Event rein machen, der Erkennt ob wir mit dem Boden, oder der Box Kollidieren

   Hier fehlen nur noch die Kollider !

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
    box.ForcedMass := 1;
    (*
     * Set the Body to moveable
     *)
    // TODO: What is the difference between Kinematic and Dynamic ?
    Box.SetRigidBodyType(krbtDynamic); // krbtKinematic ??
    box.Finish; //
    // TODO: What is this routine for ? box.SetToAwake; // Maybe a already "moving" element that lays down still needs to be SetAwake that it can move again ?
  End
  Else Begin
    box.SetRigidBodyType(krbtSTATIC);
    // If you also want to reset Rotation / Inertia and all that other stuff, see "reset" button code.
  End;
End;


Procedure TForm1.Button2Click(Sender: TObject);
Begin
  // Reset
  (*
   * Normaly you expect to reset the WorldTransform as this holds every Rotation, Position ..
   * Information, but it seems that the Engine does not update orientation if you "override" the
   * WorldTransform Matrix, so instead we set the Orientation to zero and then reset the position
   * through the SetWorldPosition method
   *)
  //box.WorldTransform := Matrix4x4Identity; //<-- This wont't work
  box.SetOrientation(0, 0, 0);
  box.SetWorldPosition(MoveableBoxStartingPosition);

  // Also reset all inertias to really get the same behavior as on "start"
  box.LinearVelocity := Vector3(0, 0, 0);
  box.AngularVelocity := Vector3(0, 0, 0);
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

