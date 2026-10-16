import { Composition } from 'remotion';
import { Quangcao, DURATION } from './Quangcao';
import { Skit, skitDuration } from './Skit';

export const Root = () => (
  <>
    <Composition id="Quangcao" component={Quangcao} durationInFrames={DURATION} fps={30} width={1080} height={1920} />
    <Composition id="Skit" component={Skit} durationInFrames={300} fps={30} width={1080} height={1920} defaultProps={{ slug: 'tinh-luong' }}
      calculateMetadata={({ props }) => ({ durationInFrames: skitDuration(props.slug) })} />
  </>
);
