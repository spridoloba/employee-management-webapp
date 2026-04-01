package net.javaguides.springboot.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;

import net.javaguides.springboot.model.Employee;
import net.javaguides.springboot.repository.EmployeeRepository;

@ExtendWith(MockitoExtension.class)
class EmployeeServiceImplTest {

	@Mock
	private EmployeeRepository employeeRepository;

	@InjectMocks
	private EmployeeServiceImpl employeeService;

	@Test
	void getAllEmployeesReturnsRepositoryResults() {
		Employee firstEmployee = new Employee();
		firstEmployee.setFirstName("Ada");
		Employee secondEmployee = new Employee();
		secondEmployee.setFirstName("Grace");
		List<Employee> employees = List.of(firstEmployee, secondEmployee);

		when(employeeRepository.findAll()).thenReturn(employees);

		assertThat(employeeService.getAllEmployees()).containsExactlyElementsOf(employees);
	}

	@Test
	void saveEmployeeDelegatesToRepository() {
		Employee employee = new Employee();
		employee.setEmail("person@example.com");

		employeeService.saveEmployee(employee);

		verify(employeeRepository).save(employee);
	}

	@Test
	void getEmployeeByIdReturnsEmployeeWhenPresent() {
		Employee employee = new Employee();
		employee.setId(7L);

		when(employeeRepository.findById(7L)).thenReturn(Optional.of(employee));

		assertThat(employeeService.getEmployeeById(7L)).isSameAs(employee);
	}

	@Test
	void getEmployeeByIdThrowsWhenMissing() {
		when(employeeRepository.findById(42L)).thenReturn(Optional.empty());

		assertThatThrownBy(() -> employeeService.getEmployeeById(42L))
			.isInstanceOf(RuntimeException.class)
			.hasMessageContaining("Employee not found for id :: 42");
	}

	@Test
	void deleteEmployeeByIdDelegatesToRepository() {
		employeeService.deleteEmployeeById(11L);

		verify(employeeRepository).deleteById(11L);
	}

	@Test
	void findPaginatedBuildsAscendingPageRequest() {
		Page<Employee> page = new PageImpl<>(List.of(new Employee()));
		when(employeeRepository.findAll(PageRequest.of(1, 5, org.springframework.data.domain.Sort.by("firstName").ascending())))
			.thenReturn(page);

		Page<Employee> result = employeeService.findPaginated(2, 5, "firstName", "asc");

		assertThat(result).isSameAs(page);
		verify(employeeRepository)
			.findAll(PageRequest.of(1, 5, org.springframework.data.domain.Sort.by("firstName").ascending()));
	}

	@Test
	void findPaginatedBuildsDescendingPageRequest() {
		Page<Employee> page = new PageImpl<>(List.of(new Employee()));
		when(employeeRepository.findAll(PageRequest.of(0, 10, org.springframework.data.domain.Sort.by("lastName").descending())))
			.thenReturn(page);

		Page<Employee> result = employeeService.findPaginated(1, 10, "lastName", "DESC");

		assertThat(result).isSameAs(page);
		verify(employeeRepository)
			.findAll(PageRequest.of(0, 10, org.springframework.data.domain.Sort.by("lastName").descending()));
	}
}
