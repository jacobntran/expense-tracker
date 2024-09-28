const apiUrl = 'http://<INSERT_LB_DNS_NAME}>:3000/api/expenses'; // Pointing to your Node.js backend
let expenses = [];
let currentEditingId = null;

async function fetchExpenses() {
    const response = await fetch(apiUrl);
    expenses = await response.json();
    renderExpenses();
}

async function addExpense() {
    const name = document.getElementById('expense-name').value;
    const amount = document.getElementById('expense-amount').value;
    const category = document.getElementById('expense-category').value;

    if (name === '' || amount === '') {
        alert('Please fill in all fields');
        return;
    }

    const expense = { name, amount: parseFloat(amount).toFixed(2), category };

    if (currentEditingId !== null) {
        await fetch(`${apiUrl}/${currentEditingId}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(expense),
        });
        currentEditingId = null;
        document.getElementById('add-button').innerText = 'Add Expense';
    } else {
        await fetch(apiUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(expense),
        });
    }

    clearForm();
    fetchExpenses();
}

async function deleteExpense(id) {
    await fetch(`${apiUrl}/${id}`, { method: 'DELETE' });
    fetchExpenses();
}

function renderExpenses() {
    const expenseList = document.getElementById('expense-list');
    expenseList.innerHTML = '';

    expenses.forEach((expense) => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${expense.name}</td>
            <td>$${expense.amount}</td>
            <td>${expense.category}</td>
            <td>
                <button onclick="editExpense(${expense.id})">Edit</button>
                <button onclick="deleteExpense(${expense.id})">Delete</button>
            </td>
        `;
        expenseList.appendChild(row);
    });
}

function editExpense(id) {
    const expense = expenses.find((expense) => expense.id === id);
    document.getElementById('expense-name').value = expense.name;
    document.getElementById('expense-amount').value = expense.amount;
    document.getElementById('expense-category').value = expense.category;
    currentEditingId = id;
    document.getElementById('add-button').innerText = 'Update Expense';
}

function clearForm() {
    document.getElementById('expense-name').value = '';
    document.getElementById('expense-amount').value = '';
    document.getElementById('expense-category').value = 'Groceries';
}

// Fetch and render the expenses when the page loads
fetchExpenses();
