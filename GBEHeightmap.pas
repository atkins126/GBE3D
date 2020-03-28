{
  Ecrit par Gr�gory Bersegeay
  Le TGBEHeightmap permet de g�n�rer un heightmap.
}
unit GBEHeightmap;

interface

uses
  System.SysUtils, System.Classes, FMX.Types, FMX.Controls3D, FMX.Objects3D, FMX.Graphics, System.Math.Vectors,
  FMX.types3D, System.UITypes, System.UIConsts, FMX.Effects, FMX.MaterialSources, System.Types, Math;

type
  TMeshHelper = class(TCustomMesh);
  TGBEHeightmap = class(TCustomMesh)
  private
    { D�clarations priv�es }
    fSubdivisions, fFlou, fMoitieCarte, fMaxMeshPlus1 : integer;
    fHeightmap, fRamp : TBitmap;
    fTracerLignes, FUseRamp : boolean;
    fMaterialLignes : TColorMaterialSource;
    fDemiHauteurSol, fMiseAEchelle : single;
    function getSubdivisions: integer;
    procedure setSubdivisions(const Value: integer);
    function getHeightmap: TBitmap;
    procedure setHeightmap(const Value: TBitmap);
    function getFlou: integer;
    procedure setFlou(const Value: integer);
    function getTracerLignes: boolean;
    procedure setTracerLignes(const Value: boolean);
    function Barycentre(p1, p2, p3: TPoint3D; p4: TPointF): single;
    function getRamp: TBitmap;
    procedure setRamp(const Value: TBitmap);
  protected
    { D�clarations prot�g�es }
    procedure Render; override;
  public
    { D�clarations publiques }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure generateHeightmap;
    function GetHeight(P: TPoint3D): single;
  published
    { D�clarations publi�es }
    property Subdivisions : integer read getSubdivisions write setSubdivisions;
    property Heightmap : TBitmap read getHeightmap write setHeightmap;
    property Ramp : TBitmap read getRamp write setRamp;
    property Flou : integer read getFlou write setFlou;
    property ShowLines : boolean read getTracerLignes write setTracerLignes;
    property MaterialLines : TColorMaterialSource read fMaterialLignes write fMaterialLignes;
    property MaterialSource;
    property Cursor default crDefault;
    property DragMode default TDragMode.dmManual;
    property Position;
    property Scale;
    property RotationAngle;
    property Locked default True;
    property Width;
    property Height;
    property Depth;
    property Opacity nodefault;
    property Projection;
    property HitTest default False;
    property UseRamp : boolean read FUseRamp write FUseRamp;
    property VisibleContextMenu default True;
    property TwoSide default False;
    property Visible default True;
    property ZWrite default True;
  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('GBE3D', [TGBEHeightmap]);
end;

{ TGBEHeightmap }

constructor TGBEHeightmap.Create(AOwner: TComponent);
begin
  inherited;
  fRamp := TBitmap.Create;
  fHeightmap := TBitmap.Create;
  ShowLines := false;
  UseRamp := false;
end;

destructor TGBEHeightmap.Destroy;
begin
  FreeAndNil(fRamp);
  FreeAndNil(fHeightmap);
  inherited;
end;

function TGBEHeightmap.getFlou: integer;
begin
  result := fFlou;
end;

function TGBEHeightmap.getHeightmap: TBitmap;
begin
  result := fHeightmap;
end;

function TGBEHeightmap.getRamp: TBitmap;
begin
  result := FRamp;
end;

function TGBEHeightmap.getSubdivisions: integer;
begin
  result := fSubdivisions;
end;

function TGBEHeightmap.getTracerLignes: boolean;
begin
  result := fTracerLignes;
end;

procedure TGBEHeightmap.Render;
begin
  inherited;
  if ShowLines then
    Context.DrawLines(self.Data.VertexBuffer, self.Data.IndexBuffer, TMaterialSource.ValidMaterial(fMaterialLignes),1);
end;

procedure TGBEHeightmap.setFlou(const Value: integer);
begin
  if value <> fFlou then fFlou := value;
end;

procedure TGBEHeightmap.setHeightmap(const Value: TBitmap);
begin
  fHeightmap.Assign(value);
end;

procedure TGBEHeightmap.setRamp(const Value: TBitmap);
begin
  fRamp.Assign(value);
end;

procedure TGBEHeightmap.setSubdivisions(const Value: integer);
begin
  if value <> fSubdivisions then fSubdivisions := value;
end;

procedure TGBEHeightmap.setTracerLignes(const Value: boolean);
begin
  if value <> fTracerLignes then fTracerLignes := value;
end;

procedure TGBEHeightmap.generateHeightmap; // Cr�ation du niveau
var
  Basic : TPlane;             // TPlane qui va servir de base
  SubMap : TBitMap;           // Bitmap qui va servir pour g�n�rer le relief � partir du heightmap
  Front, Back : PPoint3D;
  M: TMeshData;               // informations du Mesh
  G, S, W, X, Y: Integer;
  hauteurMin, zMap : Single;
  C : TAlphaColorRec;         // Couleur lue dans la heightmap et qui sert � d�terminer la hauteur d'un sommet
  bitmapData: TBitmapData;
begin
  if fSubdivisions < 1 then exit;  // il faut au moins une subdivision

  G:=fSubdivisions + 1;
  S:= G * G;  // Nombre total de maille
  hauteurMin := 0;

  self.Data.Clear;

  try
    Basic := TPlane.Create(nil);    // Cr�ation du TPlane qui va servir de base � la constitution du mesh
    Basic.SubdivisionsHeight := fSubdivisions; // le TPlane sera carr� et subdivis� pour le maillage (mesh)
    Basic.SubdivisionsWidth := fSubdivisions;

    M:=TMeshData.create;       // Cr�ation du TMesh
    M.Assign(TMeshHelper(Basic).Data); // les donn�es sont transf�r�es du TPlane au TMesh

    SubMap:=TBitmap.Create(fHeightMap.Width,fHeightMap.Height);  // Cr�ation du bitmap
    SubMap.Assign(fHeightMap);    // On charge la heightmap

    Blur(SubMap.canvas, SubMap, Flou); // On floute l'image afin d'avoir des montagnes moins anguleuses


    fDemiHauteurSol := self.Depth/2;

    if (SubMap.Map(TMapAccess.Read, bitmapData)) then  // n�cessaire pour acc�der au pixel du Bitmap afin d'en r�cup�rer la couleur
    begin
      try
        for W := 0 to S-1 do  // Parcours de tous les sommets du maillage
        begin
          Front := M.VertexBuffer.VerticesPtr[W];    // R�cup�ration des coordonn�es du sommet (TPlane subdivis� pour rappel : on a les coordonn�es en X et Y et Z est encore � 0 pour l'instant)
          Back := M.VertexBuffer.VerticesPtr[W+S];   // Pareil pour la face arri�re

//          M.VertexBuffer.VerticesPtr
          X := W mod G; // absisse du maillage en cours de traitement
          Y:=W div G; // ordonn�e du maillage en cours de traitement

          C:=TAlphaColorRec(CorrectColor(bitmapData.GetPixel(x,y))); // On r�cup�re la couleur du pixel correspondant dans la heightmap
          zMap := (C.R  + C.G  + C.B ); // d�termination de la hauteur du sommet en fonction de la couleur

          if -zMap < hauteurMin then hauteurMin := -zmap;

          if useRamp then
          begin
            M.VertexBuffer.TexCoord0[w] := Pointf(0,zmap * framp.Width / self.depth);
//            showmessage(M.TexCoordinates);
          end;

          Front^.Z := zMap; // on affecte la hauteur calcul�e � la face avant
          Back^.Z := zMap;  // pareil pour la face arri�re
        end;

        M.CalcTangentBinormals; // Calcul de vecteurs binormaux et de tangente pour toutes les faces (permet par exemple de mieux r�agir � la lumi�re)
        self.SetSize(self.width, self.Height, self.Depth);  // Pr�paration du TMesh
        self.Data.Clear;
        self.Data.Assign(M);  // On affecte les donn�es du meshdata pr�c�demment calcul�es au composant TMesh
      finally
        SubMap.Unmap(bitmapData);  // On lib�re le bitmap
      end;
    end;

    fMoitieCarte := math.Floor((fsubdivisions+1)/2);
    fMaxMeshPlus1 := fSubdivisions + 1;
    fMiseAEchelle := self.Depth / (-hauteurMin);

  finally
    FreeAndNil(SubMap);
    FreeAndNil(M);
    FreeAndNil(Basic);
  end;
end;


function TGBEHeightmap.Barycentre(p1, p2, p3 : TPoint3D; p4 : TPointF):single;
var
  det, l1, l2, l3, d1, d2, d3,  t1,t2 : single;
begin
  d1 := (p2.z - p3.z);  // Petites optimisations pour ne faire les calculs interm�diaires qu'une seule fois � chaque it�ration
  d2 := (p3.x - p2.x);
  d3 := (p1.x - p3.x);
  det := 1 / ((d1 * d3) + (d2 * (p1.z - p3.z))); // Inverse, permet de remplacer les divisions gourmandes par une multiplication (ainsi, on ne fait la division qu'une fois au lieu de deux � chaque it�ration)
  t1 := (p4.x - p3.x);
  t2 := (p4.y - p3.z);
  l1  := (( d1 * t1) + (d2 * t2 )) * det;
  l2  := ((p3.z - p1.z) * (t1 + (d3 * t2 ))) * det;
  l3  := 1 - l1 - l2;
  result := l1 * p1.y + l2 * p2.y + l3 * p3.y;
end;

function TGBEHeightmap.GetHeight(P: TPoint3D) : single;
var
   grilleX, grilleZ : integer;
   xCoord, zCoord, hauteurCalculee : single; // coordonn�es X et Z dans le "carr�"
begin
  // D�termination des indices permettant d'acc�der a sommet en fonction de la position du joueur
  grilleX := Math.Floor(P.X+fMoitieCarte);
  grilleZ := Math.Floor(P.Z+fMoitieCarte);

  // Si on est en dehors du mSol, on force (arbitrairement) la hauteur � la hauteur de la mer
  if (grilleX >= fSubdivisions) or (grilleZ >= fSubdivisions) or (grilleX < 0) or (grilleZ < 0) then
  begin
    result := -(self.Depth*1/2);
  end
  else
  begin
    xCoord := Frac(P.X); // position X dans la maille courante
    zCoord := Frac(P.Z); // position y dans la maille courante

    // On calcule la hauteur en fonction des 3 sommets du triangle dans lequel se trouve le joueur
    // On d�termine dans quel triangle on est
    if xCoord <= (1 - zCoord) then
    begin
      hauteurCalculee := Barycentre(TPoint3D.Create(0,-self.data.VertexBuffer.Vertices[grilleX + (grilleZ * fMaxMeshPlus1)].Z,0),
                                  TPoint3D.Create(1,-self.data.VertexBuffer.Vertices[grilleX +1+ (grilleZ * fMaxMeshPlus1)].Z,0),
                                  TPoint3D.Create(0,-self.data.VertexBuffer.Vertices[grilleX + ((grilleZ +1)* fMaxMeshPlus1)].Z,1),
                                  TPointF.Create(xCoord, zCoord));
    end
    else
    begin
      hauteurCalculee := Barycentre(TPoint3D.Create(1,-self.data.VertexBuffer.Vertices[grilleX +1+ (grilleZ * fMaxMeshPlus1)].Z,0),
                                  TPoint3D.Create(1,-self.data.VertexBuffer.Vertices[grilleX +1+ ((grilleZ +1) * fMaxMeshPlus1)].Z,1),
                                  TPoint3D.Create(0,-self.data.VertexBuffer.Vertices[grilleX + ((grilleZ +1)* fMaxMeshPlus1)].Z,1),
                                  TPointF.Create(xCoord, zCoord));
    end;

    hauteurCalculee := hauteurCalculee * fMiseAEchelle + fDemiHauteurSol;  // Hauteur calcul�e et mise � l'�chelle (size 50 dans CreerIle et prise en compte des demis hauteurs)
    result := hauteurCalculee;
  end;
end;

end.
