import { LightningElement, api } from 'lwc';
import { QUESTION_TYPE } from 'c/surveyConstants';

export default class SurveyQuestion extends LightningElement {
	@api question;

	get questionLabel() {
		return `${this.question.orderNumber}: ${this.question.question}`;
	}

	get isRequired() {
		return this.question.required;
	}

	get isFreeText() {
		return this.question.questionType?.trim() === QUESTION_TYPE.FREE_TEXT;
	}

	get isSingleSelect() {
		const type = this.question.questionType?.trim();
		return type === QUESTION_TYPE.SINGLE_SELECT_VERTICAL || type === QUESTION_TYPE.SINGLE_SELECT_HORIZONTAL;
	}

	get isMultiSelect() {
		return this.question.questionType?.trim() === QUESTION_TYPE.MULTI_SELECT_VERTICAL;
	}

	get hasChoices() {
		return this.question.choices && this.question.choices.length > 0;
	}

	handleResponseChange(event) {
		const value = event.target.value;
		const checked = event.target.checked;

		// Dispatch custom event to parent
		const responseEvent = new CustomEvent('responsechange', {
			detail: {
				questionId: this.question.id,
				value: value,
				checked: checked,
				questionType: this.question.questionType
			}
		});
		this.dispatchEvent(responseEvent);
	}
}
