import unittest
import nmidi


type SimpleReader = ref object
  count: int
  data: seq[uint8]


proc read(s: SimpleReader): uint8 =
  result = s.data[s.count]
  inc s.count


suite "read midi":
  test "basic read":
    type TestCase = object
      r: SimpleReader
      expStatus: Status
      expChannel: uint8
      expData: seq[uint8]

    let testCases = [
      TestCase(
        r: SimpleReader(count: 0, data: @[0x8a, 0x0f, 0x0a]),
        expStatus: NoteOff,
        expChannel: 0x0a,
        expData: @[0x0f, 0x0a]
      ),
    ]

    for testCase in testCases:
      var act: MidiAction
      testCase.r.getMidiAction(act)
      check act.st == testCase.expStatus
      check act.channel == testCase.expChannel
      check act.offNote == testCase.expData[0]
      check act.offVelocity == testCase.expData[1]

  test "runing status":
    let sreader = SimpleReader(count: 0, data: @[0x8a, 0x0f, 0x0a, 0xc, 0xd])
    var act: MidiAction
    sreader.getMidiAction(act)
    check act.st == NoteOff
    check act.channel == 0xa
    check act.offNote == 0x0f
    check act.offVelocity == 0x0a

    sreader.getMidiAction(act)
    check act.st == NoteOff
    check act.channel == 0xa
    check act.offNote == 0x0c
    check act.offVelocity == 0x0d
