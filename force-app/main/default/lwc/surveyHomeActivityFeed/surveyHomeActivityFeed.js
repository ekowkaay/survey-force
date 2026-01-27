import { LightningElement, api } from 'lwc';

/**
 * Activity Feed for Survey Force Home
 * Displays recent operational events
 */
export default class SurveyHomeActivityFeed extends LightningElement {
	@api homeData;

	get activities() {
		if (!this.homeData || !this.homeData.activities) {
			return [];
		}

		return this.homeData.activities.map((activity) => ({
			...activity,
			iconName: this.getIconForActivityType(activity.type),
			iconVariant: this.getVariantForActivityType(activity.type),
			formattedTime: this.formatTimestamp(activity.timestamp)
		}));
	}

	get hasActivities() {
		return this.activities && this.activities.length > 0;
	}

	get emptyStateMessage() {
		return 'No recent activity. Create your first survey to get started!';
	}

	getIconForActivityType(type) {
		const iconMap = {
			created: 'utility:new',
			published: 'utility:publish',
			response: 'utility:success',
			link: 'utility:link'
		};
		return iconMap[type] || 'utility:info';
	}

	getVariantForActivityType(type) {
		const variantMap = {
			created: 'warning',
			published: 'success',
			response: 'success',
			link: 'warning'
		};
		return variantMap[type] || 'default';
	}

	formatTimestamp(timestamp) {
		if (!timestamp) {
			return '';
		}

		const date = new Date(timestamp);
		const now = new Date();
		const diffMs = now - date;
		const diffMins = Math.floor(diffMs / 60000);
		const diffHours = Math.floor(diffMs / 3600000);
		const diffDays = Math.floor(diffMs / 86400000);

		if (diffMins < 1) {
			return 'Just now';
		} else if (diffMins < 60) {
			return `${diffMins} ${diffMins === 1 ? 'minute' : 'minutes'} ago`;
		} else if (diffHours < 24) {
			return `${diffHours} ${diffHours === 1 ? 'hour' : 'hours'} ago`;
		} else if (diffDays < 7) {
			return `${diffDays} ${diffDays === 1 ? 'day' : 'days'} ago`;
		} else {
			return date.toLocaleDateString();
		}
	}
}
