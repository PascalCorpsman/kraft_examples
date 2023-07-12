Program project1;

{$MODE objfpc}{$H+}

Uses
{$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
{$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, imagesforlazarus, Unit1, kraftAdditionals;

Begin
  Application.Title:='';
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
End.
