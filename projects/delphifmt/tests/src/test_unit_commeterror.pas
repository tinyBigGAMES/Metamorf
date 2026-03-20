(* a block comment *)
unit test_unit_commeterror;

interface

(* a block comment *)
type
  TDropsComments = record
    AItem: Integer;        //will be lost
    Another: string;       //  after format
  end;

(*
This is also gone
*)
implementation

{ Same here }
procedure Foo; //test
begin
end;

end.
