import { memo } from 'react';

export interface SpinePlayerProps {
	skelFile: string;
	atlasFile: string;
	onLoadFailed: (message: string) => void;
}

const SpinePlayerDisabled = memo((_props: SpinePlayerProps) => (
	<div role="status" style={{ padding: 24 }}>
		Spine preview is unavailable in this build.
	</div>
));

export default SpinePlayerDisabled;
