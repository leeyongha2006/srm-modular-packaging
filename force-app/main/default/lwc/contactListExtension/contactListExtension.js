/**
 * 예제 모듈 1: 거래처의 연락처 목록. 슬롯이 recordId 와 등록의 속성(maxRows)을 넘겨준다.
 */
import { LightningElement, api, wire } from "lwc";
import { getRelatedListRecords } from "lightning/uiRelatedListApi";

export default class ContactListExtension extends LightningElement {
    @api recordId;
    @api maxRows = 5;

    contacts = [];
    errorMessage;

    @wire(getRelatedListRecords, {
        parentRecordId: "$recordId",
        relatedListId: "Contacts",
        fields: ["Contact.Name", "Contact.Title"],
        pageSize: "$maxRows"
    })
    wiredContacts({ data, error }) {
        if (error) {
            this.errorMessage = error.body ? error.body.message : error.message;
            return;
        }
        if (data) {
            this.contacts = data.records.map((record) => ({
                id: record.id,
                name: record.fields.Name.value,
                title: record.fields.Title.value
            }));
        }
    }

    get isEmpty() {
        return this.contacts.length === 0;
    }
}