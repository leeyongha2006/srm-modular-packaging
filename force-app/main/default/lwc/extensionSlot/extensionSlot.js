/**
 * Page_Extension__mdt 에 등록된 컴포넌트를 이 자리에 그린다.
 * 컴포넌트는 실행 시점에 동적으로 불러오므로, 이 슬롯은 어떤 모듈도 직접 참조하지 않는다.
 * 설치되지 않은 컴포넌트를 가리키는 등록은 조용히 건너뛴다 (나머지 탭은 그대로 보인다).
 */
import { LightningElement, api, wire } from "lwc";
import getExtensions from "@salesforce/apex/PageExtensionController.getExtensions";

const LAYOUT_STACK = "stack";

export default class ExtensionSlot extends LightningElement {
    @api recordId;
    @api objectApiName;
    @api slotName = "Tabs";
    @api layout = "tabs"; // tabs | stack

    extensions = [];
    errorMessage;

    @wire(getExtensions, { objectApiName: "$objectApiName", slotName: "$slotName" })
    async wiredExtensions({ data, error }) {
        if (error) {
            this.errorMessage = error.body ? error.body.message : error.message;
            this.extensions = [];
            return;
        }
        if (!data) {
            return;
        }
        this.errorMessage = undefined;
        const loaded = await Promise.all(data.map((registration) => this.load(registration)));
        this.extensions = loaded.filter((extension) => extension !== null);
    }

    async load(registration) {
        try {
            const module = await import(registration.componentModule);
            return {
                key: registration.key,
                label: registration.label,
                ctor: module.default,
                props: { ...this.parseProperties(registration), recordId: this.recordId }
            };
        } catch (error) {
            // 모듈이 지워졌는데 등록만 남은 경우. 사용자가 조치할 일이 아니라 관리자용 로그만 남긴다.
            console.error(`[extensionSlot] ${registration.componentModule} could not be loaded`, error);
            return null;
        }
    }

    parseProperties(registration) {
        if (!registration.propertiesJson) {
            return {};
        }
        try {
            return JSON.parse(registration.propertiesJson);
        } catch (error) {
            console.error(`[extensionSlot] invalid PropertiesJson__c on ${registration.key}`, error);
            return {};
        }
    }

    get hasExtensions() {
        return this.extensions.length > 0;
    }

    get isStack() {
        return this.layout === LAYOUT_STACK;
    }
}