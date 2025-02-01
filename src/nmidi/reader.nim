type
  Reader* = concept  ## \
  ## A Reader is any type that provides a read proc returning uint8.
  ## This allows for this library to remain architecture-agnostic.
  ## NOTE: this may change in the near future to account for errors.
    proc read(r: Self): uint8

  Status* = enum ## \
  ## MIDI possible status codes. Not interchangeable with their underlying
  ## values - they are not mapped to the actual status byte values.
    NoteOff
    NoteOn
    PolyPress
    CtlChange
    PrgChange
    ChanPress
    PitchBend
    System
    Error

  MidiError = enum
    StatusExpected
    DataExpected
    InvalidStatus

  MidiAction* = object ## \
  ## A midi action is
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
    of Error:
      error: MidiError

const
  nextNum = ## \
      ## After a specific status word is received, the next 'n' words are to be
      ## data ones. This table encodes a status <-> # data words relation.
      [2.uint8, 2, 2, 2, 1, 1, 2, 0]
  biggestRead = 2


template numDataWords*(st: Status): uint8 =
  const
    base = cast[uint8](NoteOff)
    idx  = cast[uint8](st)
  NextNum[st-base]


proc statusFromByte(b: uint8, st: var Status): bool =
  const statusOffset = 0x8
  let val = (b and 0xf0'u8) shr 4
  if val < 0x08 or val > 0x0f:
    return false
  st = cast[Status](((b and 0xf0'u8) shr 4) - statusOffset)
  true


template isStatusWord(w: uint8): bool =
  (w and 0b10000000) > 0


template makeError(handle: var MidiAction, err: MidiError) =
  handle = MidiAction(st: Error, error: err)


proc getMidiAction*(reader: Reader, act: var MidiAction) =
  ## midi state machine implementation
  var
    readBuf: array[biggestRead, uint8]
    status: Status
    chan: uint8
    start = 0'u8

  let byte = reader.read()

  if isStatusWord(byte):
    chan = (byte and 0x0f'u8)
    if not statusFromByte(byte, status):
      makeError(act, InvalidStatus)
      return
  else:
    status = act.st
    chan = act.channel
    readBuf[0] = byte
    inc start

    if status == Error:
      makeError(act, StatusExpected)
      return

  let numReads = nextNum[cast[uint8](status)]
  for i in start..<numReads:
    readBuf[i] = reader.read()
    if isStatusWord(readBuf[i]):
      makeError(act, DataExpected)
      return

  case status
  of NoteOff:
    act = MidiAction(st: NoteOff, offNote: readBuf[0], offVelocity: readBuf[1])
  of NoteOn:
    act = MidiAction(st: NoteOn, onNote: readBuf[0], onVelocity: readBuf[1])
  of PolyPress:
    act = MidiAction(st: PolyPress, polyNote: readBuf[0], polyPressure: readBuf[1])
  of CtlChange:
    act = MidiAction(st: CtlChange, controller: readBuf[0], value: readBuf[1])
  of PrgChange:
    act = MidiAction(st: PrgChange, program: readBuf[0])
  of ChanPress:
    act = MidiAction(st: ChanPress, chanPressure: readBuf[0])
  of PitchBend:
    let
      lsb = readBuf[0]
      msb = readBuf[1]
      bend = (msb.uint16 shl 7) or (lsb.uint16)
    act = MidiAction(st: PitchBend, bend: bend)
  of System:
    # act = MidiAction(st: System, Note: r.read())
    discard
  of Error:
    discard
  act.channel = chan
