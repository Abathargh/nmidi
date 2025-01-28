type
  Reader* = concept
    proc read(r: Self): uint8

  Status* = enum
    NoteOff
    NoteOn
    PolyPress
    CtlChange
    PrgChange
    ChanPress
    PitchBend
    System

  MidiAction* = object
    channel*: uint8
    case st*: Status
    of NoteOff:
      offNote*: uint8
      offvelocity*: uint8
    of NoteOn:
      onNote*: uint8
      onVelocity*: uint8
    of PolyPress:
      polyNote*: uint8
      polyPressure*: uint8
    of CtlChange:
      controller*: uint8
      value*: uint8
    of PrgChange:
      program*: uint8
    of ChanPress:
      chanPressure*: uint8
    of PitchBend:
      bend*: uint16
    of System:
      Note*: uint8 # TODO implement

const
  statusOffset = 0x8
  NextNum = ## \
      ## After a specific status word is received, the next 'n' words are to be
      ## data ones. This table encodes a status <-> # data words relation.
      [2.uint8, 2, 2, 2, 1, 1, 2, 0]


template numDataWords*(st: Status): uint8 =
  const
    base = cast[uint8](NoteOff)
    idx  = cast[uint8](st)
  NextNum[st-base]


proc statusFromByte(b: uint8, st: var Status): bool =
  let val = (b and 0xf0'u8) shr 4
  if val < 0x08 or val > 0x0f:
    return false
  st = cast[Status](((b and 0xf0'u8) shr 4) - statusOffset)
  true


template isStatusWord*(w: uint8): bool =
  (w and 0b10000000) > 0


proc getMidiAction*(r: Reader, act: var MidiAction): bool =
  ## midi state machine implementation
  let b = r.read()
  if not isStatusWord(b):
    echo b
    return false # TODO error enum instead?

  let chan = (b and 0x0f'u8)
  var st: Status
  if not statusFromByte(b, st):
    return false # TODO error enum instead?

  case st
  of NoteOff:
    act = MidiAction(st: NoteOff, offNote: r.read(), offVelocity: r.read())
  of NoteOn:
    act = MidiAction(st: NoteOn, onNote: r.read(), onVelocity: r.read())
  of PolyPress:
    act = MidiAction(st: PolyPress, polyNote: r.read(), polyPressure: r.read())
  of CtlChange:
    act = MidiAction(st: CtlChange, controller: r.read(), value: r.read())
  of PrgChange:
    act = MidiAction(st: PrgChange, program: r.read())
  of ChanPress:
    act = MidiAction(st: ChanPress, chanPressure: r.read())
  of PitchBend:
    let
      lsb = r.read()
      msb = r.read()
      bend = (msb.uint16 shl 7) or (lsb.uint16)
    act = MidiAction(st: PitchBend, bend: r.read())
  of System:
    # act = MidiAction(st: System, Note: r.read())
    return false # TODO implement
  else:
    return false # TODO error enum instead?

  act.channel = chan
  true
