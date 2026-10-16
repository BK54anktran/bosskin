import { Composition } from 'remotion';
import { Quangcao, DURATION } from './Quangcao';

export const Root = () => (
  <Composition id="Quangcao" component={Quangcao} durationInFrames={DURATION} fps={30} width={1080} height={1920} />
);
