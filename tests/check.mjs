import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const lyrics = vm.createContext({});
vm.runInContext(fs.readFileSync(new URL('../Lyrics.js', import.meta.url), 'utf8'), lyrics);
const plain = value => JSON.parse(JSON.stringify(value));
const song = lyrics.parse('\uFEFF[ar:Test]\r\n[offset:100]\r\n[00:02.5]Second\n[00:00.10][00:05.000]First\n[00:03.00]\n[00:02.50]Translation');
assert.deepEqual(plain(song), {synced: true, lines: [
  {time: 0, text: 'First'}, {time: 2400, text: 'Second\nTranslation'},
  {time: 2900, text: ''}, {time: 4900, text: 'First'},
]});
assert.equal(lyrics.currentIndex(song.lines, -1), -1);
assert.equal(lyrics.currentIndex(song.lines, 0), 0);
assert.equal(lyrics.currentIndex(song.lines, 2399), 0);
assert.equal(lyrics.currentIndex(song.lines, 2400), 1);
assert.equal(lyrics.currentIndex(song.lines, 9999), 3);
assert.equal(lyrics.currentIndex([], 0), -1);
assert.deepEqual(plain(lyrics.parse('One\n\nTwo')), {synced: false, lines: [{time: -1, text: 'One'}, {time: -1, text: 'Two'}]});
assert.equal(lyrics.parse('[00:01.1]A').lines[0].time, 1100);
assert.equal(lyrics.parse('[00:01.01]A').lines[0].time, 1010);
assert.equal(lyrics.parse('[00:01.001]A').lines[0].time, 1001);
assert.equal(lyrics.parse('[00:01]<00:01.2>Hello <00:01.4>world').lines[0].text, 'Hello world');
assert.equal(lyrics.parse('[offset:-500]\n[00:01]A').lines[0].time, 1500);
assert.equal(lyrics.parse('[00:01]مرحبا 世界').lines[0].text, 'مرحبا 世界');
assert.throws(() => lyrics.parse('a'.repeat(131073)), /character limit/);
assert.throws(() => lyrics.fromRecord(null), /invalid/);
assert.equal(lyrics.fromRecord({instrumental: true}).instrumental, true);
assert.equal(lyrics.fromRecord({plainLyrics: 'Words'}).synced, false);
assert.equal(lyrics.validDocument({lines: [{time: 'wrong', text: 'x'}], synced: true}), false);
assert.equal(lyrics.validDocument(song), true);
assert.equal(lyrics.timeLabel(251.9), '4:11');
assert.equal(lyrics.timeLabel(NaN), '0:00');
assert.equal(lyrics.retryDelay('120', 0), 120000);
assert.equal(lyrics.retryDelay('invalid', 0), 60000);
assert.equal(lyrics.retryDelay('Thu, 01 Jan 1970 00:02:00 GMT', 0), 120000);
const track = {id:'spotify:track:a', title:'One & Two', artist:'A/B', album:'Live', duration:42};
assert.match(lyrics.query(track), /track_name=One%20%26%20Two/);
assert.notEqual(lyrics.trackKey(track), lyrics.trackKey({...track, id:'spotify:track:b'}));
assert.notEqual(lyrics.trackKey(track), lyrics.trackKey({...track, duration:84}));
assert.equal(lyrics.trackKey(track), lyrics.trackKey({...track, duration:42.1}));
console.log('Lyrics checks passed: parsing, timestamps, gaps, Unicode, validation, identity, and rate limits.');
