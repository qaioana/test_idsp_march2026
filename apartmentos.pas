program ApartmentOS;

{ ============================================================
  ApartmentOS - Apartment Association Cost Manager
  Written in standard Pascal (ISO 7185 compatible).
  Compile with: fpc apartmentos.pas  (Free Pascal Compiler)
  Data is persisted in "apartmentos.dat" in the same folder.
  ============================================================ }

const
  MAX_APARTMENTS   = 50;
  MAX_BILLS        = 200;
  MAX_READINGS     = 500;
  ADMIN_EMAIL      = 'admin@sunriseresidents.com';
  ADMIN_PASSWORD   = 'admin123';
  DATA_FILE        = 'apartmentos.dat';
  FILE_VERSION     = 1;

{ ── Type Definitions ───────────────────────────────────────── }

type
  TString60  = string[60];
  TString30  = string[30];
  TString7   = string[7];   { YYYY-MM }

  TApartment = record
    Id       : integer;
    Number   : TString10;
    Owner    : TString60;
    AreaSqM  : real;
    Email    : TString60;
    Password : TString30;
    Active   : boolean;
  end;

  TBill = record
    Id          : integer;
    Category    : TString30;
    Month       : TString7;
    TotalAmount : real;
    SplitMethod : char;   { 'E' = equal, 'A' = by area }
    Note        : TString60;
    PaidFlags   : array[1..MAX_APARTMENTS] of boolean;
    Active      : boolean;
  end;

  TWaterReading = record
    ApartmentId : integer;
    Month       : TString7;
    Reading     : real;
    Active      : boolean;
  end;

  TAssociation = record
    Name        : TString60;
    Address     : TString60;
    OfficeHours : TString60;
    AdminName   : TString60;
    AdminEmail  : TString60;
    AdminPhone  : TString30;
  end;

  TString10 = string[10];

{ ── Global State ───────────────────────────────────────────── }

var
  Apartments    : array[1..MAX_APARTMENTS] of TApartment;
  ApartmentCount: integer;

  Bills         : array[1..MAX_BILLS] of TBill;
  BillCount     : integer;

  WaterReadings : array[1..MAX_READINGS] of TWaterReading;
  ReadingCount  : integer;

  Association   : TAssociation;

  NextAptId     : integer;
  NextBillId    : integer;

  CurrentRole   : char;    { 'A' = admin, 'M' = member, ' ' = none }
  CurrentAptIdx : integer; { index into Apartments array, -1 if admin }

{ ============================================================
  UTILITY PROCEDURES
  ============================================================ }

procedure ClearScreen;
var i: integer;
begin
  for i := 1 to 40 do writeln;
end;

procedure PrintLine(ch: char; len: integer);
var i: integer;
begin
  for i := 1 to len do write(ch);
  writeln;
end;

procedure PrintHeader(title: string);
begin
  writeln;
  PrintLine('=', 56);
  writeln('  ', title);
  PrintLine('=', 56);
end;

procedure Pause;
var dummy: string;
begin
  writeln;
  write('  Press ENTER to continue...');
  readln(dummy);
end;

function ReadString(prompt: string): string;
var s: string;
begin
  write('  ', prompt, ': ');
  readln(s);
  ReadString := s;
end;

function ReadReal(prompt: string): real;
var r: real;
    s: string;
    code: integer;
begin
  repeat
    write('  ', prompt, ': ');
    readln(s);
    val(s, r, code);
    if code <> 0 then writeln('  Invalid number, try again.');
  until code = 0;
  ReadReal := r;
end;

function ReadInt(prompt: string): integer;
var n: integer;
    s: string;
    code: integer;
begin
  repeat
    write('  ', prompt, ': ');
    readln(s);
    val(s, n, code);
    if code <> 0 then writeln('  Invalid number, try again.');
  until code = 0;
  ReadInt := n;
end;

function ReadChoice(prompt: string; lo, hi: integer): integer;
var n: integer;
    s: string;
    code: integer;
begin
  repeat
    write('  ', prompt, ' (', lo, '-', hi, '): ');
    readln(s);
    val(s, n, code);
    if (code <> 0) or (n < lo) or (n > hi) then
      writeln('  Please enter a number between ', lo, ' and ', hi, '.')
  until (code = 0) and (n >= lo) and (n <= hi);
  ReadChoice := n;
end;

function RealToStr(r: real; decimals: integer): string;
var s: string;
begin
  str(r:10:decimals, s);
  { trim leading spaces }
  while (length(s) > 1) and (s[1] = ' ') do
    delete(s, 1, 1);
  RealToStr := s;
end;

function StrUpper(s: string): string;
var i: integer;
begin
  for i := 1 to length(s) do
    if s[i] in ['a'..'z'] then
      s[i] := chr(ord(s[i]) - 32);
  StrUpper := s;
end;

function FormatMonth(ym: TString7): string;
{ Converts YYYY-MM to e.g. "January 2025" }
const
  MonthNames: array[1..12] of string =
    ('January','February','March','April','May','June',
     'July','August','September','October','November','December');
var
  m, code: integer;
  mStr: string;
begin
  mStr := copy(ym, 6, 2);
  val(mStr, m, code);
  if (code = 0) and (m >= 1) and (m <= 12) then
    FormatMonth := MonthNames[m] + ' ' + copy(ym, 1, 4)
  else
    FormatMonth := ym;
end;

function ValidMonth(ym: string): boolean;
{ Validates YYYY-MM format }
var m, y, code: integer;
begin
  ValidMonth := false;
  if length(ym) <> 7 then exit;
  if ym[5] <> '-' then exit;
  val(copy(ym, 1, 4), y, code); if code <> 0 then exit;
  val(copy(ym, 6, 2), m, code); if code <> 0 then exit;
  if (m < 1) or (m > 12) then exit;
  ValidMonth := true;
end;

{ ============================================================
  DATA: FILE I/O
  ============================================================ }

procedure SaveData;
var
  f: text;
  i, j: integer;
begin
  assign(f, DATA_FILE);
  rewrite(f);

  { Header }
  writeln(f, 'APARTMENTOS_V', FILE_VERSION);

  { Association }
  writeln(f, 'ASSOC');
  writeln(f, Association.Name);
  writeln(f, Association.Address);
  writeln(f, Association.OfficeHours);
  writeln(f, Association.AdminName);
  writeln(f, Association.AdminEmail);
  writeln(f, Association.AdminPhone);

  { Apartments }
  writeln(f, 'APTS ', ApartmentCount);
  for i := 1 to ApartmentCount do
    with Apartments[i] do
      writeln(f, Id, '|', Number, '|', Owner, '|',
              RealToStr(AreaSqM, 2), '|', Email, '|', Password);

  writeln(f, 'NEXTIDS ', NextAptId, ' ', NextBillId);

  { Bills }
  writeln(f, 'BILLS ', BillCount);
  for i := 1 to BillCount do
    with Bills[i] do
      if Active then begin
        write(f, Id, '|', Category, '|', Month, '|',
              RealToStr(TotalAmount, 2), '|', SplitMethod, '|', Note, '|');
        for j := 1 to MAX_APARTMENTS do
          if PaidFlags[j] then write(f, j, ',');
        writeln(f);
      end;

  { Water Readings }
  writeln(f, 'WATER ', ReadingCount);
  for i := 1 to ReadingCount do
    with WaterReadings[i] do
      if Active then
        writeln(f, ApartmentId, '|', Month, '|', RealToStr(Reading, 2));

  close(f);
end;

function SplitField(s: string; var rest: string): string;
{ Extracts first pipe-delimited field from s, returns it, rest = remainder }
var p: integer;
begin
  p := pos('|', s);
  if p = 0 then begin
    SplitField := s;
    rest := '';
  end else begin
    SplitField := copy(s, 1, p - 1);
    rest := copy(s, p + 1, length(s));
  end;
end;

procedure LoadData;
var
  f: text;
  line, rest, field: string;
  i, j, n, code, aptid: integer;
  r: real;
  header: string;
begin
  { Set defaults }
  ApartmentCount := 0;
  BillCount      := 0;
  ReadingCount   := 0;
  NextAptId      := 1;
  NextBillId     := 1;

  Association.Name        := 'Sunrise Residents Association';
  Association.Address     := '12 Maple Street, Block B, City 10001';
  Association.OfficeHours := 'Mon-Fri: 09:00-17:00, Sat: 10:00-13:00';
  Association.AdminName   := 'Maria Popescu';
  Association.AdminEmail  := ADMIN_EMAIL;
  Association.AdminPhone  := '+40 721 000 000';

  { Check if file exists by attempting to open }
  assign(f, DATA_FILE);
  {$I-}
  reset(f);
  {$I+}
  if ioresult <> 0 then begin
    { No file yet — seed demo apartments }
    ApartmentCount := 3;
    NextAptId := 4;

    Apartments[1].Id := 1; Apartments[1].Number := '101';
    Apartments[1].Owner := 'Alice Johnson'; Apartments[1].AreaSqM := 65;
    Apartments[1].Email := 'alice@email.com'; Apartments[1].Password := 'alice123';

    Apartments[2].Id := 2; Apartments[2].Number := '102';
    Apartments[2].Owner := 'Bob Smith'; Apartments[2].AreaSqM := 80;
    Apartments[2].Email := 'bob@email.com'; Apartments[2].Password := 'bob123';

    Apartments[3].Id := 3; Apartments[3].Number := '201';
    Apartments[3].Owner := 'Carol White'; Apartments[3].AreaSqM := 65;
    Apartments[3].Email := 'carol@email.com'; Apartments[3].Password := 'carol123';

    SaveData;
    exit;
  end;

  readln(f, header); { APARTMENTOS_V1 }

  { Association }
  readln(f, line); { 'ASSOC' }
  readln(f, Association.Name);
  readln(f, Association.Address);
  readln(f, Association.OfficeHours);
  readln(f, Association.AdminName);
  readln(f, Association.AdminEmail);
  readln(f, Association.AdminPhone);

  { Apartments }
  readln(f, line); { 'APTS n' }
  val(copy(line, 6, length(line)), n, code);
  ApartmentCount := n;
  for i := 1 to ApartmentCount do begin
    readln(f, line);
    rest := line;
    field := SplitField(rest, rest); val(field, Apartments[i].Id, code);
    Apartments[i].Number   := SplitField(rest, rest);
    Apartments[i].Owner    := SplitField(rest, rest);
    field := SplitField(rest, rest); val(field, Apartments[i].AreaSqM, code);
    Apartments[i].Email    := SplitField(rest, rest);
    Apartments[i].Password := SplitField(rest, rest);
    Apartments[i].Active   := true;
  end;

  { Next IDs }
  readln(f, line);
  val(copy(line, 9, 4), NextAptId, code);
  val(copy(line, 14, 4), NextBillId, code);

  { Bills }
  readln(f, line);
  val(copy(line, 7, length(line)), n, code);
  BillCount := 0;
  for i := 1 to n do begin
    readln(f, line);
    inc(BillCount);
    rest := line;
    field := SplitField(rest, rest); val(field, Bills[BillCount].Id, code);
    Bills[BillCount].Category    := SplitField(rest, rest);
    Bills[BillCount].Month       := SplitField(rest, rest);
    field := SplitField(rest, rest); val(field, Bills[BillCount].TotalAmount, code);
    field := SplitField(rest, rest); Bills[BillCount].SplitMethod := field[1];
    Bills[BillCount].Note        := SplitField(rest, rest);
    Bills[BillCount].Active      := true;
    for j := 1 to MAX_APARTMENTS do Bills[BillCount].PaidFlags[j] := false;
    { Parse paid apartment indices }
    field := rest;
    while length(field) > 0 do begin
      val(SplitField(field, field), j, code);
      if (code = 0) and (j >= 1) and (j <= MAX_APARTMENTS) then
        Bills[BillCount].PaidFlags[j] := true;
    end;
  end;

  { Water Readings }
  readln(f, line);
  val(copy(line, 7, length(line)), n, code);
  ReadingCount := 0;
  for i := 1 to n do begin
    readln(f, line);
    rest := line;
    inc(ReadingCount);
    field := SplitField(rest, rest); val(field, WaterReadings[ReadingCount].ApartmentId, code);
    WaterReadings[ReadingCount].Month := SplitField(rest, rest);
    field := SplitField(rest, rest); val(field, WaterReadings[ReadingCount].Reading, code);
    WaterReadings[ReadingCount].Active := true;
  end;

  close(f);
end;

{ ============================================================
  BUSINESS LOGIC
  ============================================================ }

function TotalArea: real;
var i: integer; s: real;
begin
  s := 0;
  for i := 1 to ApartmentCount do
    s := s + Apartments[i].AreaSqM;
  TotalArea := s;
end;

function GetAptShare(billIdx, aptIdx: integer): real;
var ta: real;
begin
  with Bills[billIdx] do begin
    if SplitMethod = 'A' then begin
      ta := TotalArea;
      if ta > 0 then
        GetAptShare := (Apartments[aptIdx].AreaSqM / ta) * TotalAmount
      else
        GetAptShare := 0;
    end else
      GetAptShare := TotalAmount / ApartmentCount;
  end;
end;

function FindAptByIndex(id: integer): integer;
{ Returns array index (1-based) for given apartment Id, or -1 }
var i: integer;
begin
  FindAptByIndex := -1;
  for i := 1 to ApartmentCount do
    if Apartments[i].Id = id then begin
      FindAptByIndex := i;
      exit;
    end;
end;

function AptIndexInArray(aptIdx: integer): integer;
{ Returns the position of apartment (1..ApartmentCount) used for PaidFlags }
begin
  AptIndexInArray := aptIdx; { Since PaidFlags is indexed by apartment array pos }
end;

{ ============================================================
  LOGIN
  ============================================================ }

function DoLogin: boolean;
var email, pass: string;
    i: integer;
begin
  DoLogin := false;
  PrintHeader('LOGIN — ApartmentOS');
  writeln;
  writeln('  Demo credentials:');
  writeln('    Admin  : admin@sunriseresidents.com / admin123');
  writeln('    Member : alice@email.com / alice123');
  writeln;
  email := ReadString('Email');
  pass  := ReadString('Password');

  if (email = ADMIN_EMAIL) and (pass = ADMIN_PASSWORD) then begin
    CurrentRole   := 'A';
    CurrentAptIdx := -1;
    DoLogin := true;
    exit;
  end;

  for i := 1 to ApartmentCount do
    if (Apartments[i].Email = email) and (Apartments[i].Password = pass) then begin
      CurrentRole   := 'M';
      CurrentAptIdx := i;
      DoLogin := true;
      exit;
    end;

  writeln;
  writeln('  *** Invalid email or password. ***');
  Pause;
end;

{ ============================================================
  ADMIN SCREENS
  ============================================================ }

procedure AdminDashboard;
var
  i, j: integer;
  totalUnpaid: real;
  share: real;
  lastMonth: TString7;
  lastReading: real;
  found: boolean;
begin
  PrintHeader('ADMIN DASHBOARD');

  { Stats }
  totalUnpaid := 0;
  for i := 1 to BillCount do
    if Bills[i].Active then
      for j := 1 to ApartmentCount do
        if not Bills[i].PaidFlags[j] then
          totalUnpaid := totalUnpaid + GetAptShare(i, j);

  writeln;
  writeln('  Apartments  : ', ApartmentCount);
  writeln('  Total Bills : ', BillCount);
  writeln('  Total Unpaid: EUR ', RealToStr(totalUnpaid, 2));
  writeln;
  PrintLine('-', 56);

  { Recent bills (last 5) }
  writeln('  RECENT BILLS');
  PrintLine('-', 56);
  j := 0;
  for i := BillCount downto 1 do begin
    if Bills[i].Active then begin
      writeln('  [', Bills[i].Id, '] ', Bills[i].Category,
              ' — ', FormatMonth(Bills[i].Month),
              '  EUR ', RealToStr(Bills[i].TotalAmount, 2));
      inc(j);
      if j >= 5 then break;
    end;
  end;
  if j = 0 then writeln('  No bills yet.');

  writeln;
  PrintLine('-', 56);
  writeln('  LATEST WATER READINGS PER APARTMENT');
  PrintLine('-', 56);
  for i := 1 to ApartmentCount do begin
    lastMonth := '';
    lastReading := 0;
    found := false;
    for j := 1 to ReadingCount do
      if WaterReadings[j].Active and (WaterReadings[j].ApartmentId = Apartments[i].Id) then
        if WaterReadings[j].Month > lastMonth then begin
          lastMonth := WaterReadings[j].Month;
          lastReading := WaterReadings[j].Reading;
          found := true;
        end;
    write('  Apt ', Apartments[i].Number, ' — ', Apartments[i].Owner, ': ');
    if found then
      writeln(RealToStr(lastReading, 2), ' m3 (', FormatMonth(lastMonth), ')')
    else
      writeln('No readings yet');
  end;
  Pause;
end;

procedure AdminListBills;
var
  i, j: integer;
  paidCount: integer;
begin
  PrintHeader('ALL BILLS');
  if BillCount = 0 then begin
    writeln('  No bills recorded.');
    Pause; exit;
  end;
  for i := BillCount downto 1 do
    if Bills[i].Active then begin
      paidCount := 0;
      for j := 1 to ApartmentCount do
        if Bills[i].PaidFlags[j] then inc(paidCount);
      writeln;
      writeln('  [', Bills[i].Id, '] ', Bills[i].Category,
              ' | ', FormatMonth(Bills[i].Month),
              ' | EUR ', RealToStr(Bills[i].TotalAmount, 2));
      if Bills[i].Note <> '' then
        writeln('       Note: ', Bills[i].Note);
      write('       Split: ');
      if Bills[i].SplitMethod = 'A' then writeln('By area') else writeln('Equal');
      writeln('       Paid: ', paidCount, '/', ApartmentCount, ' apartments');
    end;
  Pause;
end;

procedure AdminAddBill;
var
  newBill: TBill;
  i: integer;
  ch: string;
  monthStr: TString7;
begin
  PrintHeader('ADD NEW BILL');
  writeln;
  writeln('  Categories: 1=Water  2=Heat  3=Electricity  4=Salaries  5=Other');
  i := ReadChoice('Category', 1, 5);
  case i of
    1: newBill.Category := 'Water';
    2: newBill.Category := 'Heat';
    3: newBill.Category := 'Electricity';
    4: newBill.Category := 'Salaries';
    5: newBill.Category := 'Other';
  end;

  repeat
    monthStr := ReadString('Month (YYYY-MM)');
    if not ValidMonth(monthStr) then
      writeln('  Invalid format. Use YYYY-MM, e.g. 2025-03');
  until ValidMonth(monthStr);
  newBill.Month := monthStr;

  newBill.TotalAmount := ReadReal('Total Amount (EUR)');

  writeln('  Split method:  1=Equal  2=By apartment area');
  i := ReadChoice('Split', 1, 2);
  if i = 2 then newBill.SplitMethod := 'A' else newBill.SplitMethod := 'E';

  newBill.Note := ReadString('Note (optional, press ENTER to skip)');

  newBill.Id := NextBillId;
  newBill.Active := true;
  for i := 1 to MAX_APARTMENTS do newBill.PaidFlags[i] := false;

  inc(BillCount);
  inc(NextBillId);
  Bills[BillCount] := newBill;
  SaveData;

  writeln;
  writeln('  Bill added successfully. ID = ', newBill.Id);
  Pause;
end;

procedure AdminMarkPaid;
var
  billId, aptChoice, i, j: integer;
  found: boolean;
  billIdx: integer;
begin
  PrintHeader('MARK PAYMENT');
  writeln;
  write('  Enter Bill ID to update (or 0 to cancel): ');
  billId := ReadInt('Bill ID');
  if billId = 0 then exit;

  billIdx := -1;
  for i := 1 to BillCount do
    if Bills[i].Active and (Bills[i].Id = billId) then begin
      billIdx := i; break;
    end;

  if billIdx = -1 then begin
    writeln('  Bill not found.'); Pause; exit;
  end;

  writeln;
  writeln('  Bill: ', Bills[billIdx].Category, ' — ', FormatMonth(Bills[billIdx].Month));
  writeln('  Total: EUR ', RealToStr(Bills[billIdx].TotalAmount, 2));
  writeln;
  writeln('  Apartments:');
  for i := 1 to ApartmentCount do begin
    write('    ', i, '. Apt ', Apartments[i].Number, ' — ', Apartments[i].Owner);
    write('  Share: EUR ', RealToStr(GetAptShare(billIdx, i), 2));
    if Bills[billIdx].PaidFlags[i] then writeln('  [PAID]')
    else writeln('  [UNPAID]');
  end;

  writeln;
  aptChoice := ReadChoice('Toggle paid status for apartment #', 1, ApartmentCount);
  Bills[billIdx].PaidFlags[aptChoice] := not Bills[billIdx].PaidFlags[aptChoice];
  SaveData;

  if Bills[billIdx].PaidFlags[aptChoice] then
    writeln('  Marked as PAID.')
  else
    writeln('  Marked as UNPAID.');
  Pause;
end;

procedure AdminDeleteBill;
var
  billId, i: integer;
  ch: string;
begin
  PrintHeader('DELETE BILL');
  billId := ReadInt('Bill ID to delete (0=cancel)');
  if billId = 0 then exit;
  for i := 1 to BillCount do
    if Bills[i].Active and (Bills[i].Id = billId) then begin
      write('  Delete "', Bills[i].Category, ' — ', FormatMonth(Bills[i].Month), '"? (yes/no): ');
      readln(ch);
      if ch = 'yes' then begin
        Bills[i].Active := false;
        SaveData;
        writeln('  Deleted.');
      end else
        writeln('  Cancelled.');
      Pause; exit;
    end;
  writeln('  Bill not found.'); Pause;
end;

procedure AdminBillsMenu;
var ch: integer;
begin
  repeat
    PrintHeader('ADMIN — BILLS');
    writeln;
    writeln('  1. View all bills');
    writeln('  2. Add new bill');
    writeln('  3. Mark payment (paid/unpaid)');
    writeln('  4. Delete bill');
    writeln('  0. Back');
    writeln;
    ch := ReadChoice('Choice', 0, 4);
    case ch of
      1: AdminListBills;
      2: AdminAddBill;
      3: AdminMarkPaid;
      4: AdminDeleteBill;
    end;
  until ch = 0;
end;

procedure AdminListApartments;
var i: integer;
begin
  PrintHeader('APARTMENTS');
  writeln;
  if ApartmentCount = 0 then begin writeln('  No apartments.'); Pause; exit; end;
  for i := 1 to ApartmentCount do
    writeln('  [', Apartments[i].Id, '] Apt ', Apartments[i].Number,
            ' — ', Apartments[i].Owner,
            ' (', RealToStr(Apartments[i].AreaSqM, 1), ' m2)',
            '  Login: ', Apartments[i].Email);
  Pause;
end;

procedure AdminAddApartment;
var a: TApartment;
begin
  PrintHeader('ADD APARTMENT');
  writeln;
  a.Number   := ReadString('Apartment number (e.g. 302)');
  a.Owner    := ReadString('Owner full name');
  a.AreaSqM  := ReadReal('Area in m2');
  a.Email    := ReadString('Login email');
  a.Password := ReadString('Login password');
  a.Id       := NextAptId;
  a.Active   := true;
  inc(NextAptId);
  inc(ApartmentCount);
  Apartments[ApartmentCount] := a;
  SaveData;
  writeln;
  writeln('  Apartment added. ID = ', a.Id);
  Pause;
end;

procedure AdminRemoveApartment;
var
  i, j: integer;
  ch: string;
  aptId: integer;
begin
  PrintHeader('REMOVE APARTMENT');
  AdminListApartments;
  aptId := ReadInt('Apartment ID to remove (0=cancel)');
  if aptId = 0 then exit;
  for i := 1 to ApartmentCount do
    if Apartments[i].Id = aptId then begin
      write('  Remove Apt ', Apartments[i].Number, ' — ', Apartments[i].Owner, '? (yes/no): ');
      readln(ch);
      if ch = 'yes' then begin
        for j := i to ApartmentCount - 1 do
          Apartments[j] := Apartments[j + 1];
        dec(ApartmentCount);
        SaveData;
        writeln('  Removed.');
      end else writeln('  Cancelled.');
      Pause; exit;
    end;
  writeln('  Not found.'); Pause;
end;

procedure AdminApartmentsMenu;
var ch: integer;
begin
  repeat
    PrintHeader('ADMIN — APARTMENTS');
    writeln;
    writeln('  1. List apartments');
    writeln('  2. Add apartment');
    writeln('  3. Remove apartment');
    writeln('  0. Back');
    writeln;
    ch := ReadChoice('Choice', 0, 3);
    case ch of
      1: AdminListApartments;
      2: AdminAddApartment;
      3: AdminRemoveApartment;
    end;
  until ch = 0;
end;

procedure AdminEditAssociation;
var s: string;
begin
  PrintHeader('ASSOCIATION SETTINGS');
  writeln;
  writeln('  Press ENTER to keep current value.');
  writeln;

  write('  Name [', Association.Name, ']: '); readln(s);
  if s <> '' then Association.Name := s;

  write('  Address [', Association.Address, ']: '); readln(s);
  if s <> '' then Association.Address := s;

  write('  Office Hours [', Association.OfficeHours, ']: '); readln(s);
  if s <> '' then Association.OfficeHours := s;

  write('  Admin Name [', Association.AdminName, ']: '); readln(s);
  if s <> '' then Association.AdminName := s;

  write('  Admin Email [', Association.AdminEmail, ']: '); readln(s);
  if s <> '' then Association.AdminEmail := s;

  write('  Admin Phone [', Association.AdminPhone, ']: '); readln(s);
  if s <> '' then Association.AdminPhone := s;

  SaveData;
  writeln;
  writeln('  Settings saved.');
  Pause;
end;

procedure AdminMenu;
var ch: integer;
begin
  repeat
    PrintHeader('ADMIN MENU');
    writeln;
    writeln('  1. Dashboard');
    writeln('  2. Bills');
    writeln('  3. Apartments & Accounts');
    writeln('  4. Association Settings');
    writeln('  0. Logout');
    writeln;
    ch := ReadChoice('Choice', 0, 4);
    case ch of
      1: AdminDashboard;
      2: AdminBillsMenu;
      3: AdminApartmentsMenu;
      4: AdminEditAssociation;
    end;
  until ch = 0;
  CurrentRole := ' ';
end;

{ ============================================================
  MEMBER SCREENS
  ============================================================ }

procedure MemberDashboard;
var
  i: integer;
  totalDue: real;
  unpaidCount: integer;
  lastMonth: TString7;
  lastReading: real;
  found: boolean;
begin
  PrintHeader('MY DASHBOARD — Apt ' + Apartments[CurrentAptIdx].Number);
  writeln;
  writeln('  Welcome, ', Apartments[CurrentAptIdx].Owner);
  writeln('  Apartment ', Apartments[CurrentAptIdx].Number,
          '  |  Area: ', RealToStr(Apartments[CurrentAptIdx].AreaSqM, 1), ' m2');
  writeln;
  PrintLine('-', 56);

  totalDue := 0;
  unpaidCount := 0;
  for i := 1 to BillCount do
    if Bills[i].Active and not Bills[i].PaidFlags[CurrentAptIdx] then begin
      totalDue := totalDue + GetAptShare(i, CurrentAptIdx);
      inc(unpaidCount);
    end;

  writeln('  AMOUNT DUE   : EUR ', RealToStr(totalDue, 2));
  writeln('  UNPAID BILLS : ', unpaidCount);

  { Last water reading }
  lastMonth := ''; lastReading := 0; found := false;
  for i := 1 to ReadingCount do
    if WaterReadings[i].Active and
       (WaterReadings[i].ApartmentId = Apartments[CurrentAptIdx].Id) and
       (WaterReadings[i].Month > lastMonth) then begin
      lastMonth := WaterReadings[i].Month;
      lastReading := WaterReadings[i].Reading;
      found := true;
    end;

  write('  LAST WATER   : ');
  if found then writeln(RealToStr(lastReading, 2), ' m3 — ', FormatMonth(lastMonth))
  else writeln('No readings yet');

  writeln;
  PrintLine('-', 56);
  writeln('  UNPAID BILLS:');
  for i := BillCount downto 1 do
    if Bills[i].Active and not Bills[i].PaidFlags[CurrentAptIdx] then
      writeln('  -> ', Bills[i].Category, ' | ', FormatMonth(Bills[i].Month),
              ' | EUR ', RealToStr(GetAptShare(i, CurrentAptIdx), 2));

  Pause;
end;

procedure MemberBillHistory;
var
  i: integer;
  filter: integer;
  paid: boolean;
  shown: integer;
begin
  PrintHeader('BILL HISTORY — Apt ' + Apartments[CurrentAptIdx].Number);
  writeln;
  writeln('  Filter:  1=All  2=Unpaid  3=Paid');
  filter := ReadChoice('Filter', 1, 3);
  writeln;
  PrintLine('-', 56);
  shown := 0;
  for i := BillCount downto 1 do
    if Bills[i].Active then begin
      paid := Bills[i].PaidFlags[CurrentAptIdx];
      if (filter = 1) or
         ((filter = 2) and not paid) or
         ((filter = 3) and paid) then begin
        write('  [', Bills[i].Id, '] ', Bills[i].Category,
              ' | ', FormatMonth(Bills[i].Month),
              ' | EUR ', RealToStr(GetAptShare(i, CurrentAptIdx), 2));
        if paid then writeln('  [PAID]') else writeln('  [UNPAID]');
        if Bills[i].Note <> '' then
          writeln('       Note: ', Bills[i].Note);
        write('       Split: ');
        if Bills[i].SplitMethod = 'A' then writeln('By area')
        else writeln('Equal');
        writeln('       Bill total: EUR ', RealToStr(Bills[i].TotalAmount, 2));
        writeln;
        inc(shown);
      end;
    end;
  if shown = 0 then writeln('  No bills found.');
  Pause;
end;

procedure MemberWaterMenu;
var
  i: integer;
  ch: integer;
  monthStr: TString7;
  newReading: real;
  lastReading, prevReading: real;
  lastMonth, prevMonth: TString7;
  found: boolean;
  consumed: real;
begin
  repeat
    PrintHeader('WATER METER — Apt ' + Apartments[CurrentAptIdx].Number);
    writeln;
    writeln('  1. Submit new reading');
    writeln('  2. View reading history');
    writeln('  0. Back');
    writeln;
    ch := ReadChoice('Choice', 0, 2);

    case ch of
      1: begin
           PrintHeader('SUBMIT WATER READING');
           writeln;
           repeat
             monthStr := ReadString('Month (YYYY-MM)');
             if not ValidMonth(monthStr) then
               writeln('  Invalid format. Use YYYY-MM, e.g. 2025-03');
           until ValidMonth(monthStr);

           { Check for duplicate }
           found := false;
           for i := 1 to ReadingCount do
             if WaterReadings[i].Active and
                (WaterReadings[i].ApartmentId = Apartments[CurrentAptIdx].Id) and
                (WaterReadings[i].Month = monthStr) then
               found := true;
           if found then begin
             writeln('  A reading for this month already exists.');
             Pause; continue;
           end;

           newReading := ReadReal('Current meter reading (m3)');

           { Validate not lower than previous }
           lastReading := 0; lastMonth := '';
           for i := 1 to ReadingCount do
             if WaterReadings[i].Active and
                (WaterReadings[i].ApartmentId = Apartments[CurrentAptIdx].Id) and
                (WaterReadings[i].Month < monthStr) and
                (WaterReadings[i].Month > lastMonth) then begin
               lastMonth := WaterReadings[i].Month;
               lastReading := WaterReadings[i].Reading;
             end;
           if (lastMonth <> '') and (newReading < lastReading) then begin
             writeln('  Error: Reading cannot be lower than previous month (',
                     RealToStr(lastReading, 2), ' m3).');
             Pause; continue;
           end;

           inc(ReadingCount);
           WaterReadings[ReadingCount].ApartmentId := Apartments[CurrentAptIdx].Id;
           WaterReadings[ReadingCount].Month       := monthStr;
           WaterReadings[ReadingCount].Reading     := newReading;
           WaterReadings[ReadingCount].Active      := true;
           SaveData;

           writeln;
           writeln('  Reading submitted: ', RealToStr(newReading, 2), ' m3');
           if lastMonth <> '' then
             writeln('  Consumption since last reading: ',
                     RealToStr(newReading - lastReading, 2), ' m3');
           Pause;
         end;

      2: begin
           PrintHeader('WATER READING HISTORY');
           writeln;
           { Collect and sort readings for this apartment (simple bubble sort) }
           { Print from newest to oldest }
           found := false;
           for i := ReadingCount downto 1 do
             if WaterReadings[i].Active and
                (WaterReadings[i].ApartmentId = Apartments[CurrentAptIdx].Id) then begin
               { Find previous reading }
               prevReading := 0; prevMonth := '';
               for ch := 1 to ReadingCount do
                 if WaterReadings[ch].Active and
                    (WaterReadings[ch].ApartmentId = Apartments[CurrentAptIdx].Id) and
                    (WaterReadings[ch].Month < WaterReadings[i].Month) and
                    (WaterReadings[ch].Month > prevMonth) then begin
                   prevMonth := WaterReadings[ch].Month;
                   prevReading := WaterReadings[ch].Reading;
                 end;
               write('  ', FormatMonth(WaterReadings[i].Month),
                     ':  ', RealToStr(WaterReadings[i].Reading, 2), ' m3');
               if prevMonth <> '' then
                 writeln('  (used: ', RealToStr(WaterReadings[i].Reading - prevReading, 2), ' m3)')
               else
                 writeln('  (first reading)');
               found := true;
             end;
           if not found then writeln('  No readings yet.');
           Pause;
         end;
    end;
  until ch = 0;
end;

procedure MemberContact;
begin
  PrintHeader('ASSOCIATION INFO & CONTACT');
  writeln;
  writeln('  ASSOCIATION');
  PrintLine('-', 40);
  writeln('  Name        : ', Association.Name);
  writeln('  Address     : ', Association.Address);
  writeln('  Office Hours: ', Association.OfficeHours);
  writeln;
  writeln('  ADMINISTRATOR');
  PrintLine('-', 40);
  writeln('  Name  : ', Association.AdminName);
  writeln('  Email : ', Association.AdminEmail);
  writeln('  Phone : ', Association.AdminPhone);
  writeln;
  PrintLine('-', 40);
  writeln('  ABOUT THIS PROGRAM');
  PrintLine('-', 40);
  writeln('  ApartmentOS helps residents track monthly utility costs.');
  writeln('  Bills are issued by the administrator and split by equal');
  writeln('  share or by apartment area in m2. Submit your water meter');
  writeln('  reading each month before the 5th for accurate billing.');
  writeln('  For disputes, contact the administrator directly above.');
  Pause;
end;

procedure MemberMenu;
var ch: integer;
begin
  repeat
    PrintHeader('MEMBER MENU — Apt ' + Apartments[CurrentAptIdx].Number);
    writeln;
    writeln('  1. Dashboard');
    writeln('  2. Bill History');
    writeln('  3. Water Meter');
    writeln('  4. Association Info & Contact');
    writeln('  0. Logout');
    writeln;
    ch := ReadChoice('Choice', 0, 4);
    case ch of
      1: MemberDashboard;
      2: MemberBillHistory;
      3: MemberWaterMenu;
      4: MemberContact;
    end;
  until ch = 0;
  CurrentRole := ' ';
end;

{ ============================================================
  MAIN PROGRAM
  ============================================================ }

var
  loginOk: boolean;

begin
  CurrentRole := ' ';

  LoadData;

  writeln;
  writeln('  ==========================================');
  writeln('       ApartmentOS — Console Edition        ');
  writeln('       Written in Standard Pascal           ');
  writeln('  ==========================================');
  writeln;

  repeat
    loginOk := DoLogin;
    if loginOk then begin
      if CurrentRole = 'A' then AdminMenu
      else if CurrentRole = 'M' then MemberMenu;
    end;
    writeln;
    write('  Exit program? (yes/no): ');
    var exitChoice: string;
    readln(exitChoice);
    if exitChoice = 'yes' then break;
  until false;

  writeln;
  writeln('  Goodbye!');
end.
