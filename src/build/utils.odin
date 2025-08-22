package verde_build

import "core:fmt"
import "core:os"
import "core:os/os2"

run_cmd :: proc(cmd: ..string) -> os2.Error {
  process, start_err := os2.process_start(os2.Process_Desc{
    command=cmd,
		stdout = os2.stdout,
		stderr = os2.stderr,
	})
	if start_err != nil {
		fmt.eprintln("Error:", start_err) 
		return start_err
	}

	_, wait_err := os2.process_wait(process)
	if wait_err != nil {
		fmt.eprintln("Error:", wait_err) 
		return wait_err
	}

	return nil
}

make_directory_if_not_exist :: proc(path: string) {
	if !os.exists(path) {
		err := os2.make_directory_all(path)
		if err != nil {
      fmt.println("Err : ", err)
		}
	}
}
