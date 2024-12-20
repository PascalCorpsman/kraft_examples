Unit kraftAdditionals;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, kraft;

Type

  { TKraftShapeCone }

  TKraftShapeCone = Class(TKraftShapeConvexHull)
  public
    Constructor Create(Const APhysics: TKraft; Const ARigidBody: TKraftRigidBody; Const ARadius, AHeight: TKraftScalar; Const ARefinement: integer = 16); reintroduce; overload;
  End;

  { TKraftShapeCylinder }

  TKraftShapeCylinder = Class(TKraftShapeConvexHull)
  public
    Constructor Create(Const APhysics: TKraft; Const ARigidBody: TKraftRigidBody; Const ARadius, AHeight: TKraftScalar; Const ARefinement: integer = 16); reintroduce; overload;
  End;


Implementation

{ TKraftShapeCone }

Constructor TKraftShapeCone.Create(Const APhysics: TKraft;
  Const ARigidBody: TKraftRigidBody; Const ARadius, AHeight: TKraftScalar;
  Const ARefinement: integer);
Var
  Hull: TKraftConvexHull;
  i: Integer;
  angle: Single;
Begin
  Hull := TKraftConvexHull.Create(APhysics);
  hull.AddVertex(Vector3(0, AHeight / 2, 0));
  For i := 0 To ARefinement - 1 Do Begin
    angle := 2 * pi * i / ARefinement;
    hull.AddVertex(Vector3(cos(angle) * ARadius, -AHeight / 2, sin(angle) * ARadius));
  End;
  hull.Build();
  hull.Finish;
  Inherited Create(APhysics, ARigidBody, Hull);
End;

{ TKraftShapeCylinder }

Constructor TKraftShapeCylinder.Create(Const APhysics: TKraft;
  Const ARigidBody: TKraftRigidBody; Const ARadius, AHeight: TKraftScalar;
  Const ARefinement: integer);
Var
  Hull: TKraftConvexHull;
  i: Integer;
  angle: Single;
Begin
  Hull := TKraftConvexHull.Create(APhysics);
  // This could also be done in one single loop, but so the hull is 2 Discs instead of on "Roll"
  For i := 0 To ARefinement - 1 Do Begin
    angle := 2 * pi * i / ARefinement;
    hull.AddVertex(Vector3(cos(angle) * ARadius, AHeight / 2, sin(angle) * ARadius));
  End;
  For i := 0 To ARefinement - 1 Do Begin
    angle := 2 * pi * i / ARefinement;
    hull.AddVertex(Vector3(cos(angle) * ARadius, -AHeight / 2, sin(angle) * ARadius));
  End;
  hull.Build();
  hull.Finish;
  Inherited Create(APhysics, ARigidBody, Hull);
End;

End.

