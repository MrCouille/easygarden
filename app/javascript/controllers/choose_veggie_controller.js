import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="choose-veggie"
export default class extends Controller {
  static targets = ["comp", "field", "nextButton", "addButton", "removeButton"]
  static values = {compartmentsCount: Number}
  
  connect() {
    this.counter = 0
    this.vegetable_ids = []
    console.log("Bonjour");
    this.changeButtonState();
  }

  addVegetable(event) {
    if (this.counter >= this.compartmentsCountValue) return;

    const id = event.currentTarget.dataset.id;  //gets the #id of the vegetable in the card
    this.vegetable_ids.push(id);                //adds the #id to the vegetable_ids array
    this.counter += 1;
    this.updateField(id);
    this.changeButtonState();
  }

  removeVegetable(event) {
    const id = event.currentTarget.dataset.id
    if (!this.vegetable_ids.includes(id)) return;

    const index = this.vegetable_ids.indexOf(id); //gets the position of the #id to remove
    if (index > -1) {                             // only splice array when item is found
      this.vegetable_ids.splice(index, 1);        // 2nd parameter means remove one item only
    }
    this.counter -= 1;

    this.updateField(id)
    this.changeButtonState();
  }

  updateField(id) {
    const counterDiv = document.querySelector(`#counter_${id}`)  //select the <span #id> of the vegetable in the card
    const counter = this.vegetable_ids.filter(x => x == id).length  //counts the number of occurence of #id of given vegetable
    counterDiv.innerText = counter                                //prints the number in the <span> element
    this.fieldTarget.value = this.vegetable_ids                   //updates the value of the 'toto' field
    const removeBtn = this.removeButtonTargets.find((toto) => toto.dataset.id == id)
    if (counter == 0) {
      removeBtn.disabled = true
    } else {
      removeBtn.disabled = false
    }
  }

  changeButtonState() {
    if (this.counter > 0 && this.counter < this.compartmentsCountValue) {
      this.nextButtonTarget.disabled = true;
      this.addButtonTargets.forEach(button => {
        button.disabled = false;
      });
    } else if (this.counter === 0) {
      this.nextButtonTarget.disabled = true;
    } else if (this.counter === this.compartmentsCountValue) {
      this.nextButtonTarget.disabled = false;
      this.addButtonTargets.forEach(button => {
        button.disabled = true;
      });
    }
  }
}
