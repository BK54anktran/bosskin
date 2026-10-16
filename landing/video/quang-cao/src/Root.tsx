import { Composition } from 'remotion';
import { Quangcao, DURATION } from './Quangcao';
import { Cave, CAVE_DURATION } from './Cave';

export const Root = () => (
  <>
    <Composition id="Quangcao" component={Quangcao} durationInFrames={DURATION} fps={30} width={1080} height={1920} />
    <Composition id="Cave" component={Cave} durationInFrames={CAVE_DURATION} fps={30} width={1080} height={1920} />
  </>
);
